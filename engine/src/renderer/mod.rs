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
        let clear_color = Self::extract_background(commands);

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

        // Collect all instances
        let mut solid = Vec::new();
        let mut rounded = Vec::new();
        let mut shadows = Vec::new();

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
                _ => {}
            }
        }

        // Draw: shadows → rects → text
        if let Some(pipeline) = &self.shadow_pipeline {
            if !shadows.is_empty() {
                pipeline.draw(queue, encoder, view, width, height, &shadows);
            }
        }

        if let Some(pipeline) = &mut self.rect_pipeline {
            if !solid.is_empty() || !rounded.is_empty() {
                pipeline.draw(device, queue, encoder, view, width, height, &solid, &rounded);
            }
        }

        if let Some(text_renderer) = &mut self.text_renderer {
            let mut all_glyphs = Vec::new();
            for cmd in commands {
                if let RenderCommand::Text { x, y, content, font_size, color, weight } = cmd {
                    let glyphs = text_renderer.shape_text(
                        content, *x * scale, *y * scale, *font_size * scale, color, weight,
                    );
                    all_glyphs.extend(glyphs);
                }
            }
            if !all_glyphs.is_empty() {
                text_renderer.draw(device, queue, encoder, view, width, height, &all_glyphs);
            }
        }
    }

    fn extract_background(commands: &[RenderCommand]) -> RgbaColor {
        for cmd in commands {
            if let RenderCommand::Rect { color, .. } = cmd {
                return color.clone();
            }
        }
        RgbaColor { r: 0.0, g: 0.0, b: 0.0, a: 0.0 }
    }
}
