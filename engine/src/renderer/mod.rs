pub mod types;

use crate::commands::{RenderCommand, RgbaColor};

pub struct DesktopRenderer {
    surface_format: wgpu::TextureFormat,
}

impl DesktopRenderer {
    pub fn new(surface_format: wgpu::TextureFormat) -> Self {
        Self { surface_format }
    }

    pub fn render(
        &self,
        encoder: &mut wgpu::CommandEncoder,
        view: &wgpu::TextureView,
        commands: &[RenderCommand],
        width: u32,
        height: u32,
    ) {
        let clear_color = self.extract_background(commands);

        let _pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
            label: Some("desktop_clear"),
            color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                view,
                resolve_target: None,
                ops: wgpu::Operations {
                    load: wgpu::LoadOp::Clear(wgpu::Color {
                        r: clear_color.r as f64,
                        g: clear_color.g as f64,
                        b: clear_color.b as f64,
                        a: clear_color.a as f64,
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
        // Phase 1: just clear to background color.
        // Phase 2 will add rect/roundedrect pipelines here.

        let _ = (width, height); // will be used for uniforms in Phase 2
    }

    fn extract_background(&self, commands: &[RenderCommand]) -> RgbaColor {
        // Use the first Rect command as background, or fall back to dark gray
        for cmd in commands {
            if let RenderCommand::Rect { color, .. } = cmd {
                return color.clone();
            }
        }
        RgbaColor {
            r: 0.15,
            g: 0.15,
            b: 0.17,
            a: 1.0,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extract_background_uses_first_rect() {
        let renderer = DesktopRenderer::new(wgpu::TextureFormat::Bgra8UnormSrgb);
        let red = RgbaColor {
            r: 1.0,
            g: 0.0,
            b: 0.0,
            a: 1.0,
        };
        let commands = vec![RenderCommand::Rect {
            x: 0.0,
            y: 0.0,
            w: 1920.0,
            h: 1080.0,
            color: red.clone(),
        }];
        let bg = renderer.extract_background(&commands);
        assert_eq!(bg, red);
    }

    #[test]
    fn extract_background_default_when_empty() {
        let renderer = DesktopRenderer::new(wgpu::TextureFormat::Bgra8UnormSrgb);
        let bg = renderer.extract_background(&[]);
        assert_eq!(bg.r, 0.15);
    }
}
