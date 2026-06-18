//! Direct DRM/KMS server backend (Linux): own the display, render the compositor
//! frame via wgpu/virgl into double-buffered gbm scanout buffers, page-flip on
//! vblank. No wayland host, no GL window surface (sidesteps virgl's pbuffer-only
//! configs). Used instead of winit when no WAYLAND_DISPLAY/DISPLAY is set.

use std::fs::OpenOptions;
use std::os::fd::{AsFd, AsRawFd, BorrowedFd};

use drm::control::{connector, Device as ControlDevice};
use drm::Device as BasicDevice;
use gbm::{BufferObject, BufferObjectFlags, Format as GbmFormat};

use crate::ffi::{DesktopDelegate, EngineError};
use crate::render_server::RenderServer;

struct Card(std::fs::File);
impl AsFd for Card {
    fn as_fd(&self) -> BorrowedFd<'_> {
        self.0.as_fd()
    }
}
impl BasicDevice for Card {}
impl ControlDevice for Card {}

fn err(reason: impl ToString) -> EngineError {
    EngineError::GpuInitFailed { reason: reason.to_string() }
}

/// One scanout buffer: gbm bo + the wgpu texture aliasing it + its KMS fb.
struct Buffer {
    _bo: BufferObject<()>,
    shared: wgpu_shared_surface::SharedTexture,
    fb: drm::control::framebuffer::Handle,
}

pub fn run_drm(delegate: Box<dyn DesktopDelegate>) -> Result<(), EngineError> {
    let path = std::env::var("CLONE_DRM_CARD").unwrap_or_else(|_| "/dev/dri/card0".into());
    let file = OpenOptions::new().read(true).write(true).open(&path)
        .map_err(|e| err(format!("open {path}: {e}")))?;
    let gbm = gbm::Device::new(Card(file)).map_err(|e| err(format!("gbm device: {e}")))?;
    gbm.acquire_master_lock().map_err(|e| err(format!("DRM master: {e}")))?;

    let res = gbm.resource_handles().map_err(err)?;
    let conn = res.connectors().iter()
        .filter_map(|&h| gbm.get_connector(h, false).ok())
        .find(|c| c.state() == connector::State::Connected)
        .ok_or_else(|| err("no connected connector"))?;
    let mode = *conn.modes().first().ok_or_else(|| err("connector has no modes"))?;
    let (w, h) = mode.size();
    let (w, h) = (w as u32, h as u32);
    let crtc = conn.current_encoder()
        .and_then(|e| gbm.get_encoder(e).ok())
        .and_then(|e| e.crtc())
        .or_else(|| res.crtcs().first().copied())
        .ok_or_else(|| err("no crtc"))?;
    log::info!("DRM: connector {:?} {}x{}", conn.interface(), w, h);

    // wgpu GL (surfaceless / off-screen on virgl).
    let instance = wgpu::Instance::new(wgpu::InstanceDescriptor {
        backends: wgpu::Backends::GL,
        backend_options: wgpu::BackendOptions::default(),
        flags: wgpu::InstanceFlags::empty(),
        memory_budget_thresholds: wgpu::MemoryBudgetThresholds::default(),
        display: None,
    });
    let adapter = pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions {
        power_preference: wgpu::PowerPreference::HighPerformance,
        compatible_surface: None,
        force_fallback_adapter: false,
    })).map_err(err)?;
    log::info!("DRM adapter: {}", adapter.get_info().name);
    let mut dd = wgpu::DeviceDescriptor::default();
    dd.required_limits = adapter.limits();
    let (device, queue) = pollster::block_on(adapter.request_device(&dd)).map_err(err)?;
    wgpu_shared_surface::init_egl(&adapter);

    // Linear, non-sRGB target (KMS scans out the raw bytes).
    let format = wgpu::TextureFormat::Bgra8Unorm;
    let fourcc = GbmFormat::Xrgb8888 as u32;

    let mut make_buffer = || -> Result<Buffer, EngineError> {
        let bo = gbm.create_buffer_object::<()>(
            w, h, GbmFormat::Xrgb8888,
            BufferObjectFlags::SCANOUT | BufferObjectFlags::RENDERING,
        ).map_err(|e| err(format!("gbm bo: {e}")))?;
        let dmabuf = bo.fd().map_err(|e| err(format!("bo fd: {e}")))?;
        let stride = bo.stride();
        let modifier: u64 = bo.modifier().into();
        let shared = wgpu_shared_surface::SharedTexture::from_dmabuf_render(
            &device, dmabuf.as_raw_fd(), stride, 0, fourcc, modifier, w, h, format,
        ).map_err(err)?;
        // virtio-gpu KMS rejects addfb2-with-modifiers; legacy addfb works (linear).
        let fb = gbm.add_framebuffer(&bo, 24, 32).map_err(|e| err(format!("addfb: {e}")))?;
        Ok(Buffer { _bo: bo, shared, fb })
    };
    let mut buffers = [make_buffer()?, make_buffer()?];

    let mut render_server = RenderServer::new(&device, &queue, format, format);
    let wp = delegate.wallpaper_path();
    if !wp.is_empty() {
        render_server.load_wallpaper(&device, &queue, &wp);
    }

    // First frame on buffer 0, then set_crtc to start scanout.
    let scale = 1.0_f32;
    let mut front = 0usize;
    render_compositor(&mut render_server, &device, &queue, &buffers[front].shared, w, h, scale, &*delegate);
    gbm.set_crtc(crtc, Some(buffers[front].fb), (0, 0), &[conn.handle()], Some(mode))
        .map_err(|e| err(format!("set_crtc: {e}")))?;

    log::info!("DRM: entering render loop");
    loop {
        let back = front ^ 1;
        render_compositor(&mut render_server, &device, &queue, &buffers[back].shared, w, h, scale, &*delegate);

        // Schedule the flip on the next vblank and wait for completion.
        gbm.page_flip(crtc, buffers[back].fb, drm::control::PageFlipFlags::EVENT, None)
            .map_err(|e| err(format!("page_flip: {e}")))?;
        // Block until the page-flip-complete event arrives.
        'wait: loop {
            match gbm.receive_events() {
                Ok(events) => {
                    for ev in events {
                        if let drm::control::Event::PageFlip(_) = ev {
                            break 'wait;
                        }
                    }
                }
                Err(e) => {
                    log::warn!("DRM receive_events: {e}");
                    break 'wait;
                }
            }
        }
        front = back;
    }
}

fn render_compositor(
    render_server: &mut RenderServer,
    device: &wgpu::Device,
    queue: &wgpu::Queue,
    target: &wgpu_shared_surface::SharedTexture,
    w: u32,
    h: u32,
    scale: f32,
    delegate: &dyn DesktopDelegate,
) {
    let logical_w = (w as f32 / scale) as u32;
    let logical_h = (h as f32 / scale) as u32;
    let frames = delegate.on_composite_frame(logical_w, logical_h);
    render_server.render_frame(device, queue, target.view(), w, h, scale, &frames);
    device.poll(wgpu::PollType::wait_indefinitely()).ok();
}
