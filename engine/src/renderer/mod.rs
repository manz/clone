pub mod blur;
pub mod compositor;
pub mod rect;
pub mod shadow;
pub mod text;
pub mod types;

use crate::commands::{RenderCommand, RgbaColor};
use crate::renderer::rect::RectPipeline;
use crate::renderer::shadow::{ShadowInstance, ShadowPipeline};
use crate::renderer::text::TextRenderer;
use crate::renderer::types::RectInstance;

pub struct DesktopRenderer {
    surface_format: wgpu::TextureFormat,
    rect_pipeline: Option<RectPipeline>,
    shadow_pipeline: Option<ShadowPipeline>,
    text_renderer: Option<TextRenderer>,
}

/// Scissor state for clipping.
#[derive(Clone, Copy)]
struct Scissor {
    x: u32,
    y: u32,
    w: u32,
    h: u32,
}

/// Accumulated batch to flush.
struct Batch {
    solid: Vec<RectInstance>,
    rounded: Vec<RectInstance>,
    shadows: Vec<ShadowInstance>,
    glyphs: Vec<text::GlyphInstance>,
    scissor: Option<Scissor>,
}

impl Batch {
    fn new(scissor: Option<Scissor>) -> Self {
        Self {
            solid: Vec::new(),
            rounded: Vec::new(),
            shadows: Vec::new(),
            glyphs: Vec::new(),
            scissor,
        }
    }

    fn is_empty(&self) -> bool {
        self.solid.is_empty() && self.rounded.is_empty() && self.shadows.is_empty() && self.glyphs.is_empty()
    }
}

impl DesktopRenderer {
    pub fn new(surface_format: wgpu::TextureFormat) -> Self {
        Self {
            surface_format,
            rect_pipeline: None,
            shadow_pipeline: None,
            text_renderer: None,
        }
    }

    pub fn init_pipelines(&mut self, device: &wgpu::Device, queue: &wgpu::Queue) {
        self.rect_pipeline = Some(RectPipeline::new(device, self.surface_format));
        self.shadow_pipeline = Some(ShadowPipeline::new(device, self.surface_format));
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

        // Process commands linearly. PushClip/PopClip flush the current batch
        // and set scissor state so each window's content is fully rendered
        // (shadows + rects + text) before the next window starts.
        let mut current_scissor: Option<Scissor> = None;
        let mut batch = Batch::new(None);

        for cmd in commands {
            match cmd {
                RenderCommand::PushClip { x, y, w, h, .. } => {
                    // Flush current batch before changing scissor
                    self.flush_batch(&batch, device, queue, encoder, view, width, height);
                    current_scissor = Some(Scissor {
                        x: (x * scale) as u32,
                        y: (y * scale) as u32,
                        w: (w * scale) as u32,
                        h: (h * scale) as u32,
                    });
                    batch = Batch::new(current_scissor);
                }
                RenderCommand::PopClip => {
                    // Flush clipped batch, restore full viewport
                    self.flush_batch(&batch, device, queue, encoder, view, width, height);
                    current_scissor = None;
                    batch = Batch::new(None);
                }
                RenderCommand::Rect { x, y, w, h, color } => {
                    batch.solid.push(RectInstance {
                        rect: [x * scale, y * scale, w * scale, h * scale],
                        color: [color.r, color.g, color.b, color.a],
                        radius: 0.0,
                        _pad: [0.0; 3],
                    });
                }
                RenderCommand::RoundedRect { x, y, w, h, radius, color } => {
                    batch.rounded.push(RectInstance {
                        rect: [x * scale, y * scale, w * scale, h * scale],
                        color: [color.r, color.g, color.b, color.a],
                        radius: radius * scale,
                        _pad: [0.0; 3],
                    });
                }
                RenderCommand::Shadow { x, y, w, h, radius, blur, color, ox, oy } => {
                    batch.shadows.push(ShadowInstance {
                        rect: [x * scale, y * scale, w * scale, h * scale],
                        color: [color.r, color.g, color.b, color.a],
                        params: [*radius, *blur, ox * scale, oy * scale],
                    });
                }
                RenderCommand::Text { x, y, content, font_size, color, weight } => {
                    if let Some(text_renderer) = &mut self.text_renderer {
                        let glyphs = text_renderer.shape_text(
                            content, *x * scale, *y * scale, *font_size * scale, color, weight,
                        );
                        batch.glyphs.extend(glyphs);
                    }
                }
                _ => {}
            }
        }

        // Flush remaining
        self.flush_batch(&batch, device, queue, encoder, view, width, height);
    }

    fn flush_batch(
        &mut self,
        batch: &Batch,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        encoder: &mut wgpu::CommandEncoder,
        view: &wgpu::TextureView,
        width: u32,
        height: u32,
    ) {
        if batch.is_empty() {
            return;
        }

        // Shadows don't get clipped (they extend beyond the window)
        if let Some(pipeline) = &self.shadow_pipeline {
            if !batch.shadows.is_empty() {
                pipeline.draw(queue, encoder, view, width, height, &batch.shadows);
            }
        }

        if let Some(pipeline) = &mut self.rect_pipeline {
            if !batch.solid.is_empty() || !batch.rounded.is_empty() {
                pipeline.draw_with_scissor(
                    device, queue, encoder, view, width, height,
                    &batch.solid, &batch.rounded, batch.scissor.map(|s| (s.x, s.y, s.w, s.h)),
                );
            }
        }

        if let Some(text_renderer) = &mut self.text_renderer {
            if !batch.glyphs.is_empty() {
                text_renderer.draw_with_scissor(
                    device, queue, encoder, view, width, height, &batch.glyphs,
                    batch.scissor.map(|s| (s.x, s.y, s.w, s.h)),
                );
            }
        }
    }

    fn extract_background(commands: &[RenderCommand]) -> RgbaColor {
        for cmd in commands {
            if let RenderCommand::Rect { color, .. } = cmd {
                return color.clone();
            }
        }
        RgbaColor { r: 0.15, g: 0.15, b: 0.17, a: 1.0 }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extract_background_uses_first_rect() {
        let red = RgbaColor { r: 1.0, g: 0.0, b: 0.0, a: 1.0 };
        let commands = vec![RenderCommand::Rect {
            x: 0.0, y: 0.0, w: 1920.0, h: 1080.0, color: red.clone(),
        }];
        assert_eq!(DesktopRenderer::extract_background(&commands), red);
    }

    #[test]
    fn extract_background_default_when_empty() {
        assert_eq!(DesktopRenderer::extract_background(&[]).r, 0.15);
    }
}
