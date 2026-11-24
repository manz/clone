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

            // Zero-copy GPU texture sharing:
            // macOS: import IOSurface by global ID
            // Linux: import DMA-BUF by file descriptor
            #[cfg(target_os = "macos")]
            if sf.iosurface_id != 0 {
                self.compositor.import_shared_surface(
                    device, sf.desc.surface_id, sf.iosurface_id, 0, 0,
                );
                continue;
            }
            #[cfg(not(target_os = "macos"))]
            if sf.dmabuf_fd >= 0 {
                // Import the texture at the surface's PHYSICAL content size (the app
                // may render at 2x -> the dmabuf holds content_width px), not the
                // logical window frame. The composite then samples the full surface
                // (content_width/tex = 1) into the window quad, downscaling to fit -
                // instead of reading only the top-left of an oversized surface.
                let phys_w = surface_phys_size(sf.desc.content_width, sf.desc.width, scale);
                let phys_h = surface_phys_size(sf.desc.content_height, sf.desc.height, scale);
                self.compositor.import_shared_surface_fd(
                    device, sf.desc.surface_id, sf.dmabuf_fd,
                    sf.dmabuf_stride, sf.dmabuf_offset, sf.dmabuf_fourcc, sf.dmabuf_modifier,
                    phys_w, phys_h,
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

            // No pixel data, no iosurface, no commands - keep existing texture
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
            .map(|sf| {
                let phys_w = sf.desc.width * scale;
                let phys_h = sf.desc.height * scale;
                // Surfaces with corner radius get shadows (windows).
                // Overlays (dock, menubar, fullscreen) have radius 0 and no shadow.
                CompositeWindow {
                    surface_id: sf.desc.surface_id,
                    x: sf.desc.x * scale,
                    y: sf.desc.y * scale,
                    width: phys_w,
                    height: phys_h,
                    corner_radius: sf.desc.corner_radius * scale,
                    opacity: sf.desc.opacity,
                    shadow: sf.desc.corner_radius > 0.0,
                    // desc.content_* is the surface's PHYSICAL pixel size (same unit
                    // surface_phys_size imports the texture at) - never re-scale it,
                    // or UV samples past the texture and the content squishes.
                    content_width: if sf.desc.content_width > 0.0 { sf.desc.content_width } else { phys_w },
                    content_height: if sf.desc.content_height > 0.0 { sf.desc.content_height } else { phys_h },
                    genie_progress: sf.desc.genie_progress,
                    genie_target_x: sf.desc.genie_target_x * scale,
                    genie_target_y: sf.desc.genie_target_y * scale,
                    genie_target_w: sf.desc.genie_target_w * scale,
                }
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

/// Physical pixel size to import a surface's dmabuf at. Apps may render at a scale
/// factor (e.g. 2x), so the texture holds `content` px while the window frame is
/// `logical` pt. Always prefer the content size: the composite then samples the whole
/// surface (content/tex = 1.0) and downscales it into the window quad. The fallback
/// (`logical * scale`) only reconstructs the right size when `scale` already encodes
/// the app's render scale. When it does not - DRM scale is 1.0 but the app rendered at
/// 2x - the fallback yields the logical size, the importer declares a too-small
/// texture, and the surface is cropped to its top-left. That is the "app content does
/// not fill the window" bug; the real fix is to keep `content` populated end-to-end
/// (or make the compositor scale match the app scale, i.e. HiDPI).
fn surface_phys_size(content: f32, logical: f32, scale: f32) -> u32 {
    if content > 0.0 { content as u32 } else { (logical * scale) as u32 }
}

#[cfg(test)]
mod fill_tests {
    use super::surface_phys_size;

    #[test]
    fn content_size_fills_the_window() {
        // 600pt window rendered at 2x = 1200px content. Importing at 1200 makes the
        // UV sample content/tex = 1.0, so the surface fills the quad on downscale.
        assert_eq!(surface_phys_size(1200.0, 600.0, 1.0), 1200);
    }

    #[test]
    fn fallback_is_correct_when_scale_encodes_render_scale() {
        // The HiDPI end state: compositor scale == app scale == 2.0, so even without a
        // content size the fallback reconstructs 1200px and the window fills.
        assert_eq!(surface_phys_size(0.0, 600.0, 2.0), 1200);
    }

    #[test]
    #[ignore = "known fill bug: content_width loss crops 2x surfaces; unignore when fixed"]
    fn lost_content_must_not_underfill_a_2x_surface() {
        // REGRESSION TARGET. When content_width is momentarily unavailable (surface
        // dims nil mid-swap) and the DRM scale is 1.0, the importer must still get the
        // 1200px the app actually rendered - not the 600px logical frame, which crops
        // to the top-left quarter. Fails today: the fallback has no way to know the app
        // rendered at 2x. Unignore once content_width is kept sticky end-to-end or the
        // compositor scale matches the app scale.
        assert_eq!(surface_phys_size(0.0, 600.0, 1.0), 1200);
    }
}
