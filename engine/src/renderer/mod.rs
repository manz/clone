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

    /// Render commands into the given texture view. Commands are in LOCAL coordinates
    /// (0,0 is the surface's top-left). Scale is applied for DPI.
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
        self.render_inner(device, queue, encoder, view, commands, width, height, scale, false);
    }

    pub fn render_transparent(
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
        self.render_inner(device, queue, encoder, view, commands, width, height, scale, true);
    }

    fn render_inner(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        encoder: &mut wgpu::CommandEncoder,
        view: &wgpu::TextureView,
        commands: &[RenderCommand],
        width: u32,
        height: u32,
        scale: f32,
        transparent_clear: bool,
    ) {
        let mut clear_color = Self::extract_background(commands);
        if transparent_clear {
            clear_color.a = 0.0;
        }

        // Clear
        {
            let _pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("surface_clear"),
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

        // Process commands in draw groups separated by PushClip/PopClip.
        // Each group flushes shadows → rects → text before the next group starts,
        // ensuring that text from earlier groups doesn't overdraw later groups' backgrounds.
        let mut solid = Vec::new();
        let mut rounded = Vec::new();
        let mut shadows = Vec::new();
        let mut glyphs = Vec::new();
        let mut scissor: Option<(u32, u32, u32, u32)> = None;

        let flush = |
            device: &wgpu::Device,
            queue: &wgpu::Queue,
            encoder: &mut wgpu::CommandEncoder,
            view: &wgpu::TextureView,
            shadow_pipeline: &Option<ShadowPipeline>,
            rect_pipeline: &mut Option<RectPipeline>,
            text_renderer: &mut Option<TextRenderer>,
            solid: &mut Vec<RectInstance>,
            rounded: &mut Vec<RectInstance>,
            shadows: &mut Vec<ShadowInstance>,
            glyphs: &mut Vec<text::GlyphInstance>,
            width: u32,
            height: u32,
            scissor: Option<(u32, u32, u32, u32)>,
        | {
            if solid.is_empty() && rounded.is_empty() && shadows.is_empty() && glyphs.is_empty() {
                return;
            }
            if let Some(pipeline) = shadow_pipeline {
                if !shadows.is_empty() {
                    pipeline.draw(queue, encoder, view, width, height, shadows);
                }
            }
            if let Some(pipeline) = rect_pipeline {
                if !solid.is_empty() || !rounded.is_empty() {
                    pipeline.draw_with_scissor(device, queue, encoder, view, width, height, solid, rounded, scissor);
                }
            }
            if let Some(tr) = text_renderer {
                if !glyphs.is_empty() {
                    tr.draw_with_scissor(device, queue, encoder, view, width, height, glyphs, scissor);
                }
            }
            solid.clear();
            rounded.clear();
            shadows.clear();
            glyphs.clear();
        };

        for cmd in commands {
            match cmd {
                RenderCommand::PushClip { x, y, w, h, .. } => {
                    // Flush everything accumulated so far (before the clip)
                    flush(device, queue, encoder, view,
                          &self.shadow_pipeline, &mut self.rect_pipeline, &mut self.text_renderer,
                          &mut solid, &mut rounded, &mut shadows, &mut glyphs,
                          width, height, scissor);
                    // Clamp scissor to render target bounds
                    let sx = (x * scale) as u32;
                    let sy = (y * scale) as u32;
                    let sw = ((w * scale) as u32).min(width.saturating_sub(sx));
                    let sh = ((h * scale) as u32).min(height.saturating_sub(sy));
                    scissor = Some((sx, sy, sw, sh));
                }
                RenderCommand::PopClip => {
                    // Flush the clipped group
                    flush(device, queue, encoder, view,
                          &self.shadow_pipeline, &mut self.rect_pipeline, &mut self.text_renderer,
                          &mut solid, &mut rounded, &mut shadows, &mut glyphs,
                          width, height, scissor);
                    scissor = None;
                }
                RenderCommand::Rect { x, y, w, h, color } => {
                    solid.push(RectInstance {
                        rect: [x * scale, y * scale, w * scale, h * scale],
                        color: [color.r, color.g, color.b, color.a],
                        radius: 0.0,
                        _pad: [0.0; 3],
                    });
                }
                RenderCommand::RoundedRect { x, y, w, h, radius, color } => {
                    rounded.push(RectInstance {
                        rect: [x * scale, y * scale, w * scale, h * scale],
                        color: [color.r, color.g, color.b, color.a],
                        radius: radius * scale,
                        _pad: [0.0; 3],
                    });
                }
                RenderCommand::Shadow { x, y, w, h, radius, blur, color, ox, oy } => {
                    shadows.push(ShadowInstance {
                        rect: [x * scale, y * scale, w * scale, h * scale],
                        color: [color.r, color.g, color.b, color.a],
                        params: [*radius, *blur, ox * scale, oy * scale],
                    });
                }
                RenderCommand::Text { x, y, content, font_size, color, weight, is_icon } => {
                    if let Some(tr) = &mut self.text_renderer {
                        let g = tr.shape_text(
                            content, *x * scale, *y * scale, *font_size * scale, color, weight, *is_icon,
                        );
                        glyphs.extend(g);
                    }
                }
                _ => {}
            }
        }

        // Flush remaining
        flush(device, queue, encoder, view,
              &self.shadow_pipeline, &mut self.rect_pipeline, &mut self.text_renderer,
              &mut solid, &mut rounded, &mut shadows, &mut glyphs,
              width, height, scissor);
    }

    fn extract_background(commands: &[RenderCommand]) -> RgbaColor {
        for cmd in commands {
            match cmd {
                RenderCommand::Rect { color, .. } | RenderCommand::RoundedRect { color, .. } => {
                    return color.clone();
                }
                _ => {}
            }
        }
        RgbaColor { r: 0.0, g: 0.0, b: 0.0, a: 0.0 }
    }
}
