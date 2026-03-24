pub mod blur;
pub mod compositor;
pub mod icon;
pub mod rect;
pub mod shadow;
pub mod text;
pub mod types;
pub mod wallpaper;

use crate::commands::{RenderCommand, RgbaColor};
use crate::renderer::icon::IconPipeline;
use crate::renderer::rect::RectPipeline;
use crate::renderer::shadow::{ShadowInstance, ShadowPipeline};
use crate::renderer::text::TextRenderer;
use crate::renderer::types::RectInstance;
use crate::renderer::wallpaper::WallpaperPipeline;

pub struct DesktopRenderer {
    surface_format: wgpu::TextureFormat,
    rect_pipeline: Option<RectPipeline>,
    shadow_pipeline: Option<ShadowPipeline>,
    text_renderer: Option<TextRenderer>,
    wallpaper_pipeline: Option<WallpaperPipeline>,
    icon_pipeline: Option<IconPipeline>,
}

impl DesktopRenderer {
    pub fn new(surface_format: wgpu::TextureFormat) -> Self {
        Self {
            surface_format,
            rect_pipeline: None,
            shadow_pipeline: None,
            text_renderer: None,
            wallpaper_pipeline: None,
            icon_pipeline: None,
        }
    }

    pub fn init_pipelines(&mut self, device: &wgpu::Device, queue: &wgpu::Queue) {
        self.rect_pipeline = Some(RectPipeline::new(device, self.surface_format));
        self.shadow_pipeline = Some(ShadowPipeline::new(device, self.surface_format));
        self.text_renderer = Some(TextRenderer::new(device, queue, self.surface_format));
        self.wallpaper_pipeline = Some(WallpaperPipeline::new(device, self.surface_format));
        self.icon_pipeline = Some(IconPipeline::new(device, self.surface_format));
    }

    /// Load a wallpaper image. Called once at startup.
    pub fn load_wallpaper(&mut self, device: &wgpu::Device, queue: &wgpu::Queue, path: &str) {
        if let Some(wp) = &mut self.wallpaper_pipeline {
            wp.load(device, queue, path);
        }
    }

    /// Dump the glyph atlas to a PNG for debugging.
    pub fn dump_atlas(&self, path: &str) {
        if let Some(tr) = &self.text_renderer {
            tr.dump_atlas(path);
        }
    }

    /// Render commands into the given texture view. Commands are in LOCAL coordinates
    /// (0,0 is the surface's top-left). Scale is applied for DPI.
    pub fn render(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        encoder: &mut wgpu::CommandEncoder,
        view: &wgpu::TextureView,
        depth_view: &wgpu::TextureView,
        commands: &[RenderCommand],
        width: u32,
        height: u32,
        scale: f32,
    ) {
        self.render_inner(device, queue, encoder, view, depth_view, commands, width, height, scale, false);
    }

    pub fn render_transparent(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        encoder: &mut wgpu::CommandEncoder,
        view: &wgpu::TextureView,
        depth_view: &wgpu::TextureView,
        commands: &[RenderCommand],
        width: u32,
        height: u32,
        scale: f32,
    ) {
        self.render_inner(device, queue, encoder, view, depth_view, commands, width, height, scale, true);
    }

    fn render_inner(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        encoder: &mut wgpu::CommandEncoder,
        view: &wgpu::TextureView,
        depth_view: &wgpu::TextureView,
        commands: &[RenderCommand],
        width: u32,
        height: u32,
        scale: f32,
        transparent_clear: bool,
    ) {
        // Reset instance buffer offsets for this surface render
        if let Some(tr) = &mut self.text_renderer {
            tr.reset_instance_offset();
        }
        if let Some(rp) = &mut self.rect_pipeline {
            rp.reset_instance_offsets();
        }

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
                depth_stencil_attachment: Some(wgpu::RenderPassDepthStencilAttachment {
                    view: depth_view,
                    depth_ops: Some(wgpu::Operations {
                        load: wgpu::LoadOp::Clear(1.0),
                        store: wgpu::StoreOp::Store,
                    }),
                    stencil_ops: None,
                }),
                timestamp_writes: None,
                occlusion_query_set: None,
                multiview_mask: None,
            });
        }

        // Count drawable commands to assign z values.
        // First command = 1.0 (farthest), last = near 0.0 (closest).
        let total_drawable = commands.iter().filter(|c| matches!(c,
            RenderCommand::Rect { .. } | RenderCommand::RoundedRect { .. } |
            RenderCommand::Shadow { .. } | RenderCommand::Text { .. }
        )).count().max(1);

        // Process commands in draw groups separated by PushClip/PopClip.
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
            depth_view: &wgpu::TextureView,
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
                    pipeline.draw(queue, encoder, view, depth_view, width, height, shadows);
                }
            }
            if let Some(pipeline) = rect_pipeline {
                if !solid.is_empty() || !rounded.is_empty() {
                    pipeline.draw_with_scissor(device, queue, encoder, view, depth_view, width, height, solid, rounded, scissor);
                }
            }
            if let Some(tr) = text_renderer {
                if !glyphs.is_empty() {
                    tr.draw_with_scissor(device, queue, encoder, view, depth_view, width, height, glyphs, scissor);
                }
            }
            solid.clear();
            rounded.clear();
            shadows.clear();
            glyphs.clear();
        };

        let mut cmd_index: usize = 0;

        for cmd in commands {
            match cmd {
                RenderCommand::PushClip { x, y, w, h, .. } => {
                    flush(device, queue, encoder, view, depth_view,
                          &self.shadow_pipeline, &mut self.rect_pipeline, &mut self.text_renderer,
                          &mut solid, &mut rounded, &mut shadows, &mut glyphs,
                          width, height, scissor);
                    let sx = (x * scale) as u32;
                    let sy = (y * scale) as u32;
                    let sw = ((w * scale) as u32).min(width.saturating_sub(sx));
                    let sh = ((h * scale) as u32).min(height.saturating_sub(sy));
                    scissor = Some((sx, sy, sw, sh));
                }
                RenderCommand::PopClip => {
                    flush(device, queue, encoder, view, depth_view,
                          &self.shadow_pipeline, &mut self.rect_pipeline, &mut self.text_renderer,
                          &mut solid, &mut rounded, &mut shadows, &mut glyphs,
                          width, height, scissor);
                    scissor = None;
                }
                RenderCommand::Rect { x, y, w, h, color } => {
                    let z = 1.0 - (cmd_index as f32 / total_drawable as f32);
                    cmd_index += 1;
                    solid.push(RectInstance {
                        rect: [x * scale, y * scale, w * scale, h * scale],
                        color: [color.r, color.g, color.b, color.a],
                        radius: 0.0,
                        z,
                        _pad: [0.0; 2],
                    });
                }
                RenderCommand::RoundedRect { x, y, w, h, radius, color } => {
                    let z = 1.0 - (cmd_index as f32 / total_drawable as f32);
                    cmd_index += 1;
                    rounded.push(RectInstance {
                        rect: [x * scale, y * scale, w * scale, h * scale],
                        color: [color.r, color.g, color.b, color.a],
                        radius: radius * scale,
                        z,
                        _pad: [0.0; 2],
                    });
                }
                RenderCommand::Shadow { x, y, w, h, radius, blur, color, ox, oy } => {
                    let z = 1.0 - (cmd_index as f32 / total_drawable as f32);
                    cmd_index += 1;
                    shadows.push(ShadowInstance {
                        rect: [x * scale, y * scale, w * scale, h * scale],
                        color: [color.r, color.g, color.b, color.a],
                        params: [radius * scale, blur * scale, ox * scale, oy * scale],
                        z,
                        _pad: [0.0; 3],
                    });
                }
                RenderCommand::Text { x, y, content, font_size, color, weight, max_width } => {
                    let z = 1.0 - (cmd_index as f32 / total_drawable as f32);
                    cmd_index += 1;
                    if let Some(tr) = &mut self.text_renderer {
                        let scaled_max_width = max_width.map(|mw| mw * scale);
                        let mut g = tr.shape_text(
                            content, *x * scale, *y * scale, *font_size * scale, color, weight, scaled_max_width,
                        );
                        for glyph in &mut g {
                            glyph.z = z;
                        }
                        glyphs.extend(g);
                    }
                }
                RenderCommand::Wallpaper { .. } => {
                    // Flush pending draws, then draw wallpaper fullscreen
                    flush(device, queue, encoder, view, depth_view,
                          &self.shadow_pipeline, &mut self.rect_pipeline, &mut self.text_renderer,
                          &mut solid, &mut rounded, &mut shadows, &mut glyphs,
                          width, height, scissor);
                    if let Some(wp) = &self.wallpaper_pipeline {
                        if wp.is_loaded() {
                            wp.draw(queue, encoder, view, width, height);
                        }
                    }
                }
                RenderCommand::Icon { name, style, x, y, w, h, color } => {
                    // Flush pending batched draws before the icon draw
                    flush(device, queue, encoder, view, depth_view,
                          &self.shadow_pipeline, &mut self.rect_pipeline, &mut self.text_renderer,
                          &mut solid, &mut rounded, &mut shadows, &mut glyphs,
                          width, height, scissor);
                    let z = 1.0 - (cmd_index as f32 / total_drawable as f32);
                    cmd_index += 1;
                    if let Some(ip) = &mut self.icon_pipeline {
                        ip.draw_icon(
                            device, queue, encoder, view, depth_view,
                            width, height,
                            name, style,
                            x * scale, y * scale, w * scale, h * scale,
                            color, z, scissor,
                        );
                    }
                }
                RenderCommand::Image { .. } => {
                    // TODO: ImagePipeline for user images — currently a no-op
                }
                RenderCommand::RegisterTexture { .. } => {}
                RenderCommand::UnregisterTexture { .. } => {}
                _ => {}
            }
        }

        // Flush remaining
        flush(device, queue, encoder, view, depth_view,
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
