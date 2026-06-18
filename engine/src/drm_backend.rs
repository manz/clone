//! Direct DRM/KMS server backend (Linux): own the display, render the compositor
//! frame via wgpu/virgl into double-buffered gbm scanout buffers, page-flip on
//! vblank. No wayland host, no GL window surface (sidesteps virgl's pbuffer-only
//! configs). Used instead of winit when no WAYLAND_DISPLAY/DISPLAY is set.

use std::fs::{File, OpenOptions};
use std::os::fd::{AsFd, AsRawFd, BorrowedFd, FromRawFd, IntoRawFd, OwnedFd, RawFd};
use std::os::unix::fs::OpenOptionsExt;
use std::path::Path;

use drm::control::{connector, Device as ControlDevice};
use drm::Device as BasicDevice;
use gbm::{BufferObject, BufferObjectFlags, Format as GbmFormat};
use input::event::{
    keyboard::KeyboardEventTrait, pointer::ButtonState, Event as InputEvent, KeyboardEvent,
    PointerEvent,
};
use input::{Libinput, LibinputInterface};

use crate::ffi::{DesktopDelegate, EngineError};
use crate::render_server::RenderServer;

/// libinput device-open hook. dev is in the `input` group, so plain O_RDWR works.
struct Input;
impl LibinputInterface for Input {
    fn open_restricted(&mut self, path: &Path, flags: i32) -> Result<OwnedFd, i32> {
        OpenOptions::new()
            .custom_flags(flags)
            .read(true)
            .write((flags & libc::O_RDWR != 0) || (flags & libc::O_WRONLY != 0))
            .open(path)
            .map(|f| f.into())
            .map_err(|e| e.raw_os_error().unwrap_or(libc::EIO))
    }
    fn close_restricted(&mut self, fd: OwnedFd) {
        drop(File::from(fd));
    }
}

/// Classic arrow cursor (X = black outline, W = white fill, space = transparent).
const ARROW: [&str; 16] = [
    "X               ",
    "XX              ",
    "XWX             ",
    "XWWX            ",
    "XWWWX           ",
    "XWWWWX          ",
    "XWWWWWX         ",
    "XWWWWWWX        ",
    "XWWWWWWWX       ",
    "XWWWWWWWWX      ",
    "XWWWWWXXXXX     ",
    "XWWXWWX         ",
    "XWX XWWX        ",
    "XX  XWWX        ",
    "X    XWWX       ",
    "     XXX        ",
];

/// 64x64 ARGB8888 (B,G,R,A bytes) cursor image with the arrow at the top-left.
fn cursor_pixels() -> Vec<u8> {
    let mut px = vec![0u8; 64 * 64 * 4];
    for (row, line) in ARROW.iter().enumerate() {
        for (col, ch) in line.bytes().enumerate() {
            let i = (row * 64 + col) * 4;
            match ch {
                b'X' => px[i..i + 4].copy_from_slice(&[255, 255, 255, 255]), // white border
                b'W' => px[i..i + 4].copy_from_slice(&[0, 0, 0, 255]),       // black fill
                _ => {}
            }
        }
    }
    px
}

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

    // KMS cursor plane: a small ARGB bo with the arrow.
    // scale=1.0: logical == physical (1280x800). Apps render at 2x and the
    // surface downscales via UV (works, click coords line up). A true HiDPI
    // scale needs the whole model (apps/hit-test/menubar-width) made consistent;
    // until then 1.0 keeps the desktop usable (menubar looks half = known issue).
    let scale = 1.0_f32;
    let mut cx = (w / 2) as f64;
    let mut cy = (h / 2) as f64;
    if let Ok(mut cbo) = gbm.create_buffer_object::<()>(
        64, 64, GbmFormat::Argb8888,
        BufferObjectFlags::CURSOR | BufferObjectFlags::WRITE,
    ) {
        let _ = cbo.write(&cursor_pixels());
        let _ = gbm.set_cursor(crtc, Some(&cbo));
        let _ = gbm.move_cursor(crtc, (cx as i32, cy as i32));
        std::mem::forget(cbo); // keep the cursor bo alive for the session
    }

    // libinput from the seat's devices.
    let mut libinput = Libinput::new_with_udev(Input);
    if libinput.udev_assign_seat("seat0").is_err() {
        log::warn!("DRM: libinput udev_assign_seat failed; no input");
    }
    let li_fd = libinput.as_raw_fd();
    let drm_fd = gbm.as_fd().as_raw_fd();

    // First frame on buffer 0, then set_crtc to start scanout.
    let mut front = 0usize;
    render_compositor(&mut render_server, &device, &queue, &buffers[front].shared, w, h, scale, &*delegate);
    gbm.set_crtc(crtc, Some(buffers[front].fb), (0, 0), &[conn.handle()], Some(mode))
        .map_err(|e| err(format!("set_crtc: {e}")))?;

    log::info!("DRM: entering render loop");
    // Render continuously, paced by a poll timeout. NOT gated on the page-flip
    // event (virtio-gpu doesn't deliver it reliably, which made the loop only
    // advance on input -> "appears on hover"). page_flip self-throttles via
    // EBUSY while a flip is in flight; we just skip that frame.
    loop {
        // Pace ~60fps + wake immediately on input; drain input + any flip events.
        let mut fds = [
            libc::pollfd { fd: drm_fd, events: libc::POLLIN, revents: 0 },
            libc::pollfd { fd: li_fd, events: libc::POLLIN, revents: 0 },
        ];
        unsafe { libc::poll(fds.as_mut_ptr(), 2, 16) };
        if fds[1].revents & libc::POLLIN != 0 {
            let _ = libinput.dispatch();
            while let Some(ev) = libinput.next() {
                handle_input(ev, &*delegate, &mut cx, &mut cy, w, h, scale, &gbm, crtc);
            }
        }
        if fds[0].revents & libc::POLLIN != 0 {
            let _ = gbm.receive_events().map(|evs| evs.count());
        }

        let back = front ^ 1;
        render_compositor(&mut render_server, &device, &queue, &buffers[back].shared, w, h, scale, &*delegate);
        // EBUSY while the previous flip is pending -> skip (don't swap front).
        if gbm.page_flip(crtc, buffers[back].fb, drm::control::PageFlipFlags::EVENT, None).is_ok() {
            front = back;
        }
    }
}

/// Map a libinput event to a delegate callback; move the KMS cursor.
#[allow(clippy::too_many_arguments)]
fn handle_input(
    ev: InputEvent,
    delegate: &dyn DesktopDelegate,
    cx: &mut f64,
    cy: &mut f64,
    w: u32,
    h: u32,
    scale: f32,
    gbm: &gbm::Device<Card>,
    crtc: drm::control::crtc::Handle,
) {
    // cx/cy are PHYSICAL screen coords (cursor plane); the delegate hit-tests in
    // LOGICAL coords, so divide by scale for on_pointer_move (matches winit path).
    let s = scale as f64;
    match ev {
        InputEvent::Pointer(PointerEvent::Motion(m)) => {
            *cx = (*cx + m.dx()).clamp(0.0, (w - 1) as f64);
            *cy = (*cy + m.dy()).clamp(0.0, (h - 1) as f64);
            let _ = gbm.move_cursor(crtc, (*cx as i32, *cy as i32));
            delegate.on_pointer_move(0, *cx / s, *cy / s);
        }
        // VMs expose an absolute pointing device (tablet); handle those too.
        InputEvent::Pointer(PointerEvent::MotionAbsolute(m)) => {
            *cx = m.absolute_x_transformed(w).clamp(0.0, (w - 1) as f64);
            *cy = m.absolute_y_transformed(h).clamp(0.0, (h - 1) as f64);
            let _ = gbm.move_cursor(crtc, (*cx as i32, *cy as i32));
            delegate.on_pointer_move(0, *cx / s, *cy / s);
        }
        InputEvent::Pointer(PointerEvent::Button(b)) => {
            let btn = match b.button() {
                0x110 => 0, // BTN_LEFT
                0x111 => 1, // BTN_RIGHT
                0x112 => 2, // BTN_MIDDLE
                _ => 3,
            };
            let pressed = b.button_state() == ButtonState::Pressed;
            delegate.on_pointer_button(0, btn, pressed);
        }
        InputEvent::Pointer(PointerEvent::ScrollWheel(s)) => {
            use input::event::pointer::{Axis, PointerScrollEvent};
            let dx = if s.has_axis(Axis::Horizontal) { s.scroll_value(Axis::Horizontal) } else { 0.0 };
            let dy = if s.has_axis(Axis::Vertical) { s.scroll_value(Axis::Vertical) } else { 0.0 };
            delegate.on_scroll(0, dx, dy);
        }
        InputEvent::Keyboard(KeyboardEvent::Key(k)) => {
            let pressed = k.key_state() == input::event::keyboard::KeyState::Pressed;
            delegate.on_key(0, k.key(), 0, pressed);
        }
        _ => {}
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
    // Debug: clear to magenta instead of compositing, to verify the render-loop
    // + page-flip path displays at all (CLONE_DRM_DEBUG_CLEAR=1).
    if std::env::var_os("CLONE_DRM_DEBUG_CLEAR").is_some() {
        let mut enc = device.create_command_encoder(&Default::default());
        {
            let _pass = enc.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("debug_clear"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: target.view(),
                    resolve_target: None,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(wgpu::Color { r: 0.8, g: 0.0, b: 0.8, a: 1.0 }),
                        store: wgpu::StoreOp::Store,
                    },
                    depth_slice: None,
                })],
                depth_stencil_attachment: None,
                timestamp_writes: None,
                occlusion_query_set: None,
                multiview_mask: None,
            });
        }
        queue.submit([enc.finish()]);
        device.poll(wgpu::PollType::wait_indefinitely()).ok();
        return;
    }
    let logical_w = (w as f32 / scale) as u32;
    let logical_h = (h as f32 / scale) as u32;
    let frames = delegate.on_composite_frame(logical_w, logical_h);
    render_server.render_frame(device, queue, target.view(), w, h, scale, &frames);
    device.poll(wgpu::PollType::wait_indefinitely()).ok();
}
