use wgpu_iosurface::SharedTexture;

fn create_device() -> (wgpu::Device, wgpu::Queue) {
    let instance = wgpu::Instance::new(wgpu::InstanceDescriptor {
        backends: wgpu::Backends::METAL,
        backend_options: wgpu::BackendOptions::default(),
        flags: wgpu::InstanceFlags::default(),
        memory_budget_thresholds: wgpu::MemoryBudgetThresholds::default(),
        display: None,
    });
    let adapter = pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions {
        power_preference: wgpu::PowerPreference::HighPerformance,
        compatible_surface: None,
        force_fallback_adapter: false,
    }))
    .expect("No GPU adapter");
    pollster::block_on(adapter.request_device(&wgpu::DeviceDescriptor::default()))
        .expect("Failed to get device")
}

#[test]
fn create_shared_texture() {
    let (device, _queue) = create_device();
    let shared = SharedTexture::new(&device, 256, 256, wgpu::TextureFormat::Bgra8Unorm)
        .expect("Failed to create SharedTexture");

    assert!(shared.iosurface_id() > 0);
    assert_eq!(shared.width(), 256);
    assert_eq!(shared.height(), 256);
}

#[test]
fn import_shared_texture_by_id() {
    let (device, _queue) = create_device();

    // Create on "app side"
    let creator = SharedTexture::new(&device, 128, 64, wgpu::TextureFormat::Bgra8Unorm)
        .expect("Failed to create");

    let surface_id = creator.iosurface_id();

    // Import on "compositor side" (same process for testing, but IOSurface sharing is cross-process)
    let imported = SharedTexture::from_id(&device, surface_id, 128, 64, wgpu::TextureFormat::Bgra8Unorm)
        .expect("Failed to import");

    assert_eq!(imported.iosurface_id(), surface_id);
    assert_eq!(imported.width(), 128);
    assert_eq!(imported.height(), 64);
}

#[test]
fn render_into_shared_texture() {
    let (device, queue) = create_device();

    let shared = SharedTexture::new(&device, 64, 64, wgpu::TextureFormat::Bgra8Unorm)
        .expect("Failed to create");

    // Render a clear color into the shared texture
    let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
        label: Some("test_render"),
    });
    {
        let _pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
            label: Some("clear_pass"),
            color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                view: shared.view(),
                resolve_target: None,
                ops: wgpu::Operations {
                    load: wgpu::LoadOp::Clear(wgpu::Color::RED),
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
    queue.submit([encoder.finish()]);

    // The texture should be usable (no crash = success for GPU-backed IOSurface)
}
