//! DRM/KMS + GPU smoke test: render a solid color with wgpu (GL/virgl) INTO a
//! gbm scanout buffer, then page-flip it via KMS. Proves the wgpu->gbm->KMS
//! pipeline that the real compositor will use (offscreen GL render + KMS scanout,
//! no GL window surface needed).
//!
//! Run on the VM console as the seat session (via the cage service slot), cage
//! stopped. Screen should turn solid orange for ~5s.

#[cfg(not(target_os = "linux"))]
fn main() {
    eprintln!("drm-gpu-smoke is Linux-only");
}

#[cfg(target_os = "linux")]
fn main() {
    use std::fs::OpenOptions;
    use std::os::fd::{AsFd, AsRawFd, BorrowedFd};

    use drm::control::Device as ControlDevice;
    use drm::Device as BasicDevice;
    use gbm::{BufferObjectFlags, Format as GbmFormat};

    struct Card(std::fs::File);
    impl AsFd for Card {
        fn as_fd(&self) -> BorrowedFd<'_> {
            self.0.as_fd()
        }
    }
    impl BasicDevice for Card {}
    impl ControlDevice for Card {}

    env_logger::try_init().ok();

    let path = std::env::args().nth(1).unwrap_or_else(|| "/dev/dri/card0".into());
    let file = OpenOptions::new().read(true).write(true).open(&path)
        .unwrap_or_else(|e| panic!("open {path}: {e}"));
    let card = Card(file);
    card.acquire_master_lock().expect("acquire DRM master (stop cage first?)");

    // gbm device wraps the card; deref reaches the drm control methods.
    let gbm = gbm::Device::new(card).expect("gbm::Device::new");

    let res = gbm.resource_handles().expect("resource_handles");
    let conn = res.connectors().iter()
        .filter_map(|&h| gbm.get_connector(h, false).ok())
        .find(|c| c.state() == drm::control::connector::State::Connected)
        .expect("no connected connector");
    let mode = *conn.modes().first().expect("no modes");
    let (w, h) = mode.size();
    let crtc = conn.current_encoder()
        .and_then(|e| gbm.get_encoder(e).ok())
        .and_then(|e| e.crtc())
        .or_else(|| res.crtcs().first().copied())
        .expect("no crtc");
    println!("connector {:?}: {}x{}", conn.interface(), w, h);

    // Scanout-capable, GPU-renderable buffer object.
    let bo = gbm
        .create_buffer_object::<()>(
            w as u32, h as u32, GbmFormat::Xrgb8888,
            BufferObjectFlags::SCANOUT | BufferObjectFlags::RENDERING,
        )
        .expect("create_buffer_object");
    let dmabuf = bo.fd().expect("bo.fd");
    let stride = bo.stride();
    let modifier: u64 = bo.modifier().into();
    let fourcc: u32 = u32::from(GbmFormat::Xrgb8888 as u32); // 'XR24'
    println!("bo: stride={stride} modifier={modifier:#x} fourcc={fourcc:#x}");

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
    })).expect("adapter");
    println!("adapter: {}", adapter.get_info().name);
    // GLES 3.0 has no compute; use the adapter's actual limits, not the
    // compute-requiring defaults.
    let mut dd = wgpu::DeviceDescriptor::default();
    dd.required_limits = adapter.limits();
    let (device, queue) = pollster::block_on(adapter.request_device(&dd)).expect("device");

    wgpu_shared_surface::init_egl(&adapter);

    // Import the gbm bo's dmabuf as a wgpu render target.
    let shared = wgpu_shared_surface::SharedTexture::from_dmabuf_render(
        &device, dmabuf.as_raw_fd(), stride, 0, fourcc, modifier,
        w as u32, h as u32, wgpu::TextureFormat::Bgra8Unorm,
    ).expect("import gbm bo as render target");

    // Clear it to orange.
    let mut enc = device.create_command_encoder(&Default::default());
    {
        let _pass = enc.begin_render_pass(&wgpu::RenderPassDescriptor {
            label: Some("clear"),
            color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                view: shared.view(),
                resolve_target: None,
                ops: wgpu::Operations {
                    load: wgpu::LoadOp::Clear(wgpu::Color { r: 0.9, g: 0.45, b: 0.0, a: 1.0 }),
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

    // Scan out the bo.
    // virtio-gpu KMS rejects addfb2-with-modifiers; legacy addfb works (linear).
    let fb = gbm.add_framebuffer(&bo, 24, 32).expect("add_framebuffer");
    gbm.set_crtc(crtc, Some(fb), (0, 0), &[conn.handle()], Some(mode))
        .expect("set_crtc");
    println!("wgpu->gbm->KMS OK (orange for 5s)");
    std::thread::sleep(std::time::Duration::from_secs(5));
    gbm.destroy_framebuffer(fb).ok();
}
