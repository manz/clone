use crate::commands::SurfaceFrame;
use crate::renderer::DesktopRenderer;
use crate::surface_compositor::{CompositeWindow, SurfaceCompositor};

pub struct RenderServer {
    pub renderer: DesktopRenderer,
    pub compositor: SurfaceCompositor,
}

impl RenderServer {
    /// Create a render server.
    /// - `offscreen_format`: format for per-window offscreen textures (should be linear, e.g. Bgra8Unorm)
    /// - `screen_format`: format for the final screen surface (should be sRGB, e.g. Bgra8UnormSrgb)
    pub fn new(device: &wgpu::Device, queue: &wgpu::Queue, offscreen_format: wgpu::TextureFormat, screen_format: wgpu::TextureFormat) -> Self {
        let mut renderer = DesktopRenderer::new(offscreen_format);
        renderer.init_pipelines(device, queue);
        Self {
            renderer,
            compositor: SurfaceCompositor::new(device, offscreen_format, screen_format),
        }
    }

    pub fn load_wallpaper(&mut self, device: &wgpu::Device, queue: &wgpu::Queue, path: &str) {
        self.renderer.load_wallpaper(device, queue, path);
    }

    pub fn render_frame(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        screen_view: &wgpu::TextureView,
        width: u32,
        height: u32,
        scale: f32,
        frames: &[SurfaceFrame],
    ) {
        // Ensure offscreen textures exist for each surface (skip zero-size and IOSurface-backed)
        let mut active_ids: Vec<u64> = Vec::new();
        for sf in frames {
            let phys_w = (sf.desc.width * scale) as u32;
            let phys_h = (sf.desc.height * scale) as u32;
            if phys_w == 0 || phys_h == 0 {
                continue;
            }
            // Don't create a normal surface for IOSurface-backed windows
            if sf.iosurface_id == 0 {
                self.compositor.ensure_surface(device, sf.desc.surface_id, phys_w, phys_h);
            }
            active_ids.push(sf.desc.surface_id);
        }
        self.compositor.gc(&active_ids);

        // Render each surface's commands into its offscreen texture (skip zero-size)
        for sf in frames {
            if sf.desc.width <= 0.0 || sf.desc.height <= 0.0 { continue; }

            // IOSurface-backed: import the shared texture (zero-copy)
            if sf.iosurface_id != 0 {
                let phys_w = (sf.desc.width * scale) as u32;
                let phys_h = (sf.desc.height * scale) as u32;
                self.compositor.import_iosurface(
                    device, sf.desc.surface_id, sf.iosurface_id, phys_w, phys_h,
                );
                continue;
            }

            // Legacy: upload pre-rendered pixels directly
            if let Some(ref pixels) = sf.pixel_data {
                let phys_w = (sf.desc.width * scale) as u32;
                let phys_h = (sf.desc.height * scale) as u32;
                self.compositor.upload_pixels(
                    sf.desc.surface_id, queue, pixels, phys_w, phys_h,
                );
                continue;
            }

            // No pixel data, no iosurface, no commands — keep existing texture
            if sf.commands.is_empty() {
                continue;
            }

            // Compositor-rendered: render commands into offscreen texture
            let has_transparent_bg = sf.commands.first().map_or(true, |cmd| {
                match cmd {
                    crate::commands::RenderCommand::Rect { color, .. } |
                    crate::commands::RenderCommand::RoundedRect { color, .. } => color.a < 1.0,
                    _ => true,
                }
            });
            self.compositor.render_to_surface(
                sf.desc.surface_id,
                &mut self.renderer,
                device,
                queue,
                &sf.commands,
                scale,
                has_transparent_bg,
            );
        }

        // Clear screen
        {
            let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("screen_clear"),
            });
            {
                let _pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                    label: Some("screen_clear_pass"),
                    color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                        view: screen_view,
                        resolve_target: None,
                        ops: wgpu::Operations {
                            load: wgpu::LoadOp::Clear(wgpu::Color {
                                r: 0.0, g: 0.0, b: 0.0, a: 1.0,
                            }),
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
        }

        // Composite surfaces back-to-front
        let composite_windows: Vec<CompositeWindow> = frames
            .iter()
            .map(|sf| CompositeWindow {
                surface_id: sf.desc.surface_id,
                x: sf.desc.x * scale,
                y: sf.desc.y * scale,
                width: sf.desc.width * scale,
                height: sf.desc.height * scale,
                corner_radius: sf.desc.corner_radius * scale,
                opacity: sf.desc.opacity,
            })
            .collect();

        self.compositor.composite(
            device,
            queue,
            screen_view,
            width,
            height,
            &composite_windows,
        );
    }
}
