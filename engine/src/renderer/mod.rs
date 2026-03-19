pub mod blur;
pub mod compositor;
pub mod rect;
pub mod text;
pub mod types;

use crate::commands::{RenderCommand, RgbaColor};
use crate::renderer::rect::RectPipeline;
use crate::renderer::text::TextRenderer;
use crate::renderer::types::RectInstance;

pub struct DesktopRenderer {
    surface_format: wgpu::TextureFormat,
    rect_pipeline: Option<RectPipeline>,
    text_renderer: Option<TextRenderer>,
}

impl DesktopRenderer {
    pub fn new(surface_format: wgpu::TextureFormat) -> Self {
        Self {
            surface_format,
            rect_pipeline: None,
            text_renderer: None,
        }
    }

    /// Initialize GPU pipelines. Must be called after device is available.
    pub fn init_pipelines(&mut self, device: &wgpu::Device, queue: &wgpu::Queue) {
        self.rect_pipeline = Some(RectPipeline::new(device, self.surface_format));
        self.text_renderer = Some(TextRenderer::new(device, queue, self.surface_format));
    }

    pub fn render(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        encoder: &mut wgpu::CommandEncoder,
        view: &wgpu::TextureView,
        commands: &[RenderCommand],
        width: u32,
        height: u32,
        scale: f32,
    ) {
        let clear_color = Self::extract_background(commands);

        // Clear pass
        {
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
        }

        // Dispatch commands to pipelines — scale logical coords to physical
        let (solid, rounded) = Self::collect_instances(commands, scale);

        if let Some(pipeline) = &mut self.rect_pipeline {
            if !solid.is_empty() || !rounded.is_empty() {
                pipeline.draw(device, queue, encoder, view, width, height, &solid, &rounded);
            }
        }

        // Shape and draw text (scale positions and font size)
        if let Some(text_renderer) = &mut self.text_renderer {
            let mut all_glyphs = Vec::new();
            for cmd in commands {
                if let RenderCommand::Text {
                    x,
                    y,
                    content,
                    font_size,
                    color,
                    weight,
                } = cmd
                {
                    let glyphs = text_renderer.shape_text(
                        content,
                        *x * scale,
                        *y * scale,
                        *font_size * scale,
                        color,
                        weight,
                    );
                    all_glyphs.extend(glyphs);
                }
            }
            if !all_glyphs.is_empty() {
                text_renderer.draw(device, queue, encoder, view, width, height, &all_glyphs);
            }
        }
    }

    /// Collect RenderCommands into GPU instance arrays, scaling by DPI factor.
    fn collect_instances(commands: &[RenderCommand], scale: f32) -> (Vec<RectInstance>, Vec<RectInstance>) {
        let mut solid = Vec::new();
        let mut rounded = Vec::new();

        for cmd in commands {
            match cmd {
                RenderCommand::Rect { x, y, w, h, color } => {
                    solid.push(RectInstance {
                        rect: [x * scale, y * scale, w * scale, h * scale],
                        color: [color.r, color.g, color.b, color.a],
                        radius: 0.0,
                        _pad: [0.0; 3],
                    });
                }
                RenderCommand::RoundedRect {
                    x,
                    y,
                    w,
                    h,
                    radius,
                    color,
                } => {
                    rounded.push(RectInstance {
                        rect: [x * scale, y * scale, w * scale, h * scale],
                        color: [color.r, color.g, color.b, color.a],
                        radius: radius * scale,
                        _pad: [0.0; 3],
                    });
                }
                _ => {}
            }
        }

        (solid, rounded)
    }

    fn extract_background(commands: &[RenderCommand]) -> RgbaColor {
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
        let bg = DesktopRenderer::extract_background(&commands);
        assert_eq!(bg, red);
    }

    #[test]
    fn extract_background_default_when_empty() {
        let bg = DesktopRenderer::extract_background(&[]);
        assert_eq!(bg.r, 0.15);
    }

    #[test]
    fn collect_instances_separates_solid_and_rounded() {
        let white = RgbaColor {
            r: 1.0,
            g: 1.0,
            b: 1.0,
            a: 1.0,
        };
        let commands = vec![
            RenderCommand::Rect {
                x: 0.0,
                y: 0.0,
                w: 100.0,
                h: 50.0,
                color: white.clone(),
            },
            RenderCommand::RoundedRect {
                x: 10.0,
                y: 10.0,
                w: 80.0,
                h: 40.0,
                radius: 8.0,
                color: white.clone(),
            },
            RenderCommand::Rect {
                x: 200.0,
                y: 0.0,
                w: 50.0,
                h: 50.0,
                color: white,
            },
            RenderCommand::PopClip, // ignored
        ];

        let (solid, rounded) = DesktopRenderer::collect_instances(&commands, 1.0);
        assert_eq!(solid.len(), 2);
        assert_eq!(rounded.len(), 1);
        assert_eq!(rounded[0].radius, 8.0);
        assert_eq!(solid[0].rect, [0.0, 0.0, 100.0, 50.0]);
    }

    #[test]
    fn collect_instances_with_scale() {
        let white = RgbaColor { r: 1.0, g: 1.0, b: 1.0, a: 1.0 };
        let commands = vec![RenderCommand::Rect {
            x: 10.0, y: 20.0, w: 100.0, h: 50.0, color: white,
        }];
        let (solid, _) = DesktopRenderer::collect_instances(&commands, 2.0);
        assert_eq!(solid[0].rect, [20.0, 40.0, 200.0, 100.0]);
    }

    #[test]
    fn collect_instances_empty_commands() {
        let (solid, rounded) = DesktopRenderer::collect_instances(&[], 1.0);
        assert!(solid.is_empty());
        assert!(rounded.is_empty());
    }
}
