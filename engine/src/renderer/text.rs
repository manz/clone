use cosmic_text::{Attrs, Buffer, Family, FontSystem, Metrics, Shaping, SwashCache, Weight};
use rustc_hash::FxHashMap;
use crate::commands::RgbaColor;

/// A glyph atlas entry.
#[derive(Clone, Copy)]
struct GlyphEntry {
    x: u32,
    y: u32,
    width: u32,
    height: u32,
    left: f32,
    top: f32,
}

/// GPU-side glyph instance for instanced rendering.
#[repr(C)]
#[derive(Copy, Clone, bytemuck::Pod, bytemuck::Zeroable)]
pub struct GlyphInstance {
    pub rect: [f32; 4],    // x, y, w, h in screen pixels
    pub uv_rect: [f32; 4], // u, v, uw, vh in atlas [0..1]
    pub color: [f32; 4],   // r, g, b, a
    pub z: f32,            // depth: 0.0 = front, 1.0 = back
    pub _pad: [f32; 3],
}

const ATLAS_SIZE: u32 = 1024;
const MAX_GLYPH_INSTANCES: usize = 4096;

/// Text shaping and atlas management.
pub struct TextRenderer {
    font_system: FontSystem,
    swash_cache: SwashCache,
    atlas_data: Vec<u8>,
    atlas_cursor_x: u32,
    atlas_cursor_y: u32,
    atlas_row_height: u32,
    glyph_cache: FxHashMap<cosmic_text::CacheKey, GlyphEntry>,
    atlas_dirty: bool,

    // GPU resources
    pipeline: wgpu::RenderPipeline,
    uniform_buffer: wgpu::Buffer,
    bind_group: wgpu::BindGroup,
    bind_group_layout: wgpu::BindGroupLayout,
    atlas_texture: wgpu::Texture,
    instance_buffer: wgpu::Buffer,
    sampler: wgpu::Sampler,
}

impl TextRenderer {
    pub fn new(device: &wgpu::Device, queue: &wgpu::Queue, surface_format: wgpu::TextureFormat) -> Self {
        let mut font_system = FontSystem::new();
        // Load bundled Inter font (system UI text)
        font_system
            .db_mut()
            .load_font_data(include_bytes!("../../assets/Inter.ttf").to_vec());
        // Load bundled Phosphor icon font
        font_system
            .db_mut()
            .load_font_data(include_bytes!("../../assets/Phosphor.ttf").to_vec());
        let swash_cache = SwashCache::new();

        let atlas_data = vec![0u8; (ATLAS_SIZE * ATLAS_SIZE) as usize];

        let atlas_texture = device.create_texture(&wgpu::TextureDescriptor {
            label: Some("glyph_atlas"),
            size: wgpu::Extent3d {
                width: ATLAS_SIZE,
                height: ATLAS_SIZE,
                depth_or_array_layers: 1,
            },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: wgpu::TextureFormat::R8Unorm,
            usage: wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_DST,
            view_formats: &[],
        });

        let sampler = device.create_sampler(&wgpu::SamplerDescriptor {
            label: Some("glyph_sampler"),
            mag_filter: wgpu::FilterMode::Linear,
            min_filter: wgpu::FilterMode::Linear,
            ..Default::default()
        });

        let uniform_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("text_uniforms"),
            size: 16, // vec2 screen_size + pad
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        let bind_group_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("text_bind_group_layout"),
            entries: &[
                wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::VERTEX,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                    count: None,
                },
                wgpu::BindGroupLayoutEntry {
                    binding: 1,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Texture {
                        sample_type: wgpu::TextureSampleType::Float { filterable: true },
                        view_dimension: wgpu::TextureViewDimension::D2,
                        multisampled: false,
                    },
                    count: None,
                },
                wgpu::BindGroupLayoutEntry {
                    binding: 2,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Sampler(wgpu::SamplerBindingType::Filtering),
                    count: None,
                },
            ],
        });

        let atlas_view = atlas_texture.create_view(&Default::default());
        let bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("text_bind_group"),
            layout: &bind_group_layout,
            entries: &[
                wgpu::BindGroupEntry {
                    binding: 0,
                    resource: uniform_buffer.as_entire_binding(),
                },
                wgpu::BindGroupEntry {
                    binding: 1,
                    resource: wgpu::BindingResource::TextureView(&atlas_view),
                },
                wgpu::BindGroupEntry {
                    binding: 2,
                    resource: wgpu::BindingResource::Sampler(&sampler),
                },
            ],
        });

        let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("text_pipeline_layout"),
            bind_group_layouts: &[&bind_group_layout],
            immediate_size: 0,
        });

        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("text_sdf_shader"),
            source: wgpu::ShaderSource::Wgsl(include_str!("../shaders/text_sdf.wgsl").into()),
        });

        let instance_layout = wgpu::VertexBufferLayout {
            array_stride: std::mem::size_of::<GlyphInstance>() as u64,
            step_mode: wgpu::VertexStepMode::Instance,
            attributes: &wgpu::vertex_attr_array![
                0 => Float32x4,  // rect
                1 => Float32x4,  // uv_rect
                2 => Float32x4,  // color
                3 => Float32,    // z (depth)
                4 => Float32,    // _pad0
                5 => Float32,    // _pad1
                6 => Float32,    // _pad2
            ],
        };

        let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("text_pipeline"),
            layout: Some(&pipeline_layout),
            vertex: wgpu::VertexState {
                module: &shader,
                entry_point: Some("vs_main"),
                compilation_options: Default::default(),
                buffers: &[instance_layout],
            },
            fragment: Some(wgpu::FragmentState {
                module: &shader,
                entry_point: Some("fs_main"),
                compilation_options: Default::default(),
                targets: &[Some(wgpu::ColorTargetState {
                    format: surface_format,
                    blend: Some(wgpu::BlendState::ALPHA_BLENDING),
                    write_mask: wgpu::ColorWrites::ALL,
                })],
            }),
            primitive: wgpu::PrimitiveState {
                topology: wgpu::PrimitiveTopology::TriangleList,
                ..Default::default()
            },
            depth_stencil: Some(wgpu::DepthStencilState {
                format: wgpu::TextureFormat::Depth32Float,
                depth_write_enabled: true,
                depth_compare: wgpu::CompareFunction::Less,
                stencil: wgpu::StencilState::default(),
                bias: wgpu::DepthBiasState::default(),
            }),
            multisample: wgpu::MultisampleState::default(),
            multiview_mask: None,
            cache: None,
        });

        let instance_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("glyph_instances"),
            size: (MAX_GLYPH_INSTANCES * std::mem::size_of::<GlyphInstance>()) as u64,
            usage: wgpu::BufferUsages::VERTEX | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        Self {
            font_system,
            swash_cache,
            atlas_data,
            atlas_cursor_x: 0,
            atlas_cursor_y: 0,
            atlas_row_height: 0,
            glyph_cache: FxHashMap::default(),
            atlas_dirty: false,
            pipeline,
            uniform_buffer,
            bind_group,
            bind_group_layout,
            atlas_texture,
            instance_buffer,
            sampler,
        }
    }

    /// Shape text and produce glyph instances. Returns the list of instances to draw.
    pub fn shape_text(
        &mut self,
        content: &str,
        x: f32,
        y: f32,
        font_size: f32,
        color: &RgbaColor,
        weight: &crate::commands::FontWeight,
        is_icon: bool,
        max_width: Option<f32>,
    ) -> Vec<GlyphInstance> {
        let metrics = Metrics::new(font_size, font_size * 1.2);
        let mut buffer = Buffer::new(&mut self.font_system, metrics);

        if let Some(mw) = max_width {
            buffer.set_size(&mut self.font_system, Some(mw), None);
        }

        let cosmic_weight = match weight {
            crate::commands::FontWeight::Regular => Weight::NORMAL,
            crate::commands::FontWeight::Medium => Weight(500),
            crate::commands::FontWeight::Semibold => Weight::SEMIBOLD,
            crate::commands::FontWeight::Bold => Weight::BOLD,
        };
        let family = if is_icon {
            Family::Name("Phosphor")
        } else {
            Family::Name("Inter Variable")
        };
        let attrs = Attrs::new().family(family).weight(cosmic_weight);
        buffer.set_text(&mut self.font_system, content, attrs, Shaping::Advanced);
        buffer.shape_until_scroll(&mut self.font_system, false);

        let mut instances = Vec::new();

        for run in buffer.layout_runs() {
            for glyph in run.glyphs.iter() {
                let physical = glyph.physical((0.0, 0.0), 1.0);
                let cache_key = physical.cache_key;

                // Rasterize if not cached
                if !self.glyph_cache.contains_key(&cache_key) {
                    // Extract image data first to avoid borrow conflict
                    let glyph_data = if let Some(image) = self
                        .swash_cache
                        .get_image(&mut self.font_system, cache_key)
                    {
                        Some((
                            image.placement.width,
                            image.placement.height,
                            image.data.clone(),
                            image.placement.left as f32,
                            image.placement.top as f32,
                        ))
                    } else {
                        None
                    };

                    if let Some((w, h, data, left, top)) = glyph_data {
                        if w > 0 && h > 0 {
                            if let Some(entry) = self.pack_glyph(w, h, &data, left, top) {
                                self.glyph_cache.insert(cache_key, entry);
                            }
                        }
                    }
                }

                if let Some(entry) = self.glyph_cache.get(&cache_key) {
                    let gx = x + physical.x as f32 + entry.left;
                    let gy = y + run.line_y + physical.y as f32 - entry.top;

                    instances.push(GlyphInstance {
                        rect: [gx, gy, entry.width as f32, entry.height as f32],
                        uv_rect: [
                            entry.x as f32 / ATLAS_SIZE as f32,
                            entry.y as f32 / ATLAS_SIZE as f32,
                            entry.width as f32 / ATLAS_SIZE as f32,
                            entry.height as f32 / ATLAS_SIZE as f32,
                        ],
                        color: [color.r, color.g, color.b, color.a],
                        z: 0.0,
                        _pad: [0.0; 3],
                    });
                }
            }
        }

        instances
    }

    fn pack_glyph(&mut self, width: u32, height: u32, data: &[u8], left: f32, top: f32) -> Option<GlyphEntry> {
        // Simple row packing
        if self.atlas_cursor_x + width > ATLAS_SIZE {
            self.atlas_cursor_x = 0;
            self.atlas_cursor_y += self.atlas_row_height;
            self.atlas_row_height = 0;
        }

        if self.atlas_cursor_y + height > ATLAS_SIZE {
            return None; // Atlas full
        }

        let x = self.atlas_cursor_x;
        let y = self.atlas_cursor_y;

        // Copy glyph data into atlas (handle different data formats)
        for row in 0..height {
            for col in 0..width {
                let src_idx = (row * width + col) as usize;
                let dst_idx = ((y + row) * ATLAS_SIZE + (x + col)) as usize;
                if src_idx < data.len() && dst_idx < self.atlas_data.len() {
                    self.atlas_data[dst_idx] = data[src_idx];
                }
            }
        }

        self.atlas_cursor_x += width + 1; // 1px padding
        self.atlas_row_height = self.atlas_row_height.max(height + 1);
        self.atlas_dirty = true;

        Some(GlyphEntry {
            x,
            y,
            width,
            height,
            left,
            top,
        })
    }

    /// Upload atlas if dirty and draw all glyph instances.
    pub fn draw(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        encoder: &mut wgpu::CommandEncoder,
        view: &wgpu::TextureView,
        depth_view: &wgpu::TextureView,
        width: u32,
        height: u32,
        instances: &[GlyphInstance],
    ) {
        if instances.is_empty() {
            return;
        }

        // Upload atlas if dirty
        if self.atlas_dirty {
            queue.write_texture(
                wgpu::TexelCopyTextureInfo {
                    texture: &self.atlas_texture,
                    mip_level: 0,
                    origin: wgpu::Origin3d::ZERO,
                    aspect: wgpu::TextureAspect::All,
                },
                &self.atlas_data,
                wgpu::TexelCopyBufferLayout {
                    offset: 0,
                    bytes_per_row: Some(ATLAS_SIZE),
                    rows_per_image: Some(ATLAS_SIZE),
                },
                wgpu::Extent3d {
                    width: ATLAS_SIZE,
                    height: ATLAS_SIZE,
                    depth_or_array_layers: 1,
                },
            );

            // Rebuild bind group with new atlas view
            let atlas_view = self.atlas_texture.create_view(&Default::default());
            self.bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
                label: Some("text_bind_group"),
                layout: &self.bind_group_layout,
                entries: &[
                    wgpu::BindGroupEntry {
                        binding: 0,
                        resource: self.uniform_buffer.as_entire_binding(),
                    },
                    wgpu::BindGroupEntry {
                        binding: 1,
                        resource: wgpu::BindingResource::TextureView(&atlas_view),
                    },
                    wgpu::BindGroupEntry {
                        binding: 2,
                        resource: wgpu::BindingResource::Sampler(&self.sampler),
                    },
                ],
            });

            self.atlas_dirty = false;
        }

        // Update uniforms
        let uniforms: [f32; 4] = [width as f32, height as f32, 0.0, 0.0];
        queue.write_buffer(&self.uniform_buffer, 0, bytemuck::cast_slice(&uniforms));

        // Upload instances
        let count = instances.len().min(MAX_GLYPH_INSTANCES);
        queue.write_buffer(
            &self.instance_buffer,
            0,
            bytemuck::cast_slice(&instances[..count]),
        );

        // Draw
        let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
            label: Some("text_pass"),
            color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                view,
                resolve_target: None,
                ops: wgpu::Operations {
                    load: wgpu::LoadOp::Load,
                    store: wgpu::StoreOp::Store,
                },
                depth_slice: None,
            })],
            depth_stencil_attachment: Some(wgpu::RenderPassDepthStencilAttachment {
                view: depth_view,
                depth_ops: Some(wgpu::Operations {
                    load: wgpu::LoadOp::Load,
                    store: wgpu::StoreOp::Store,
                }),
                stencil_ops: None,
            }),
            timestamp_writes: None,
            occlusion_query_set: None,
            multiview_mask: None,
        });

        pass.set_pipeline(&self.pipeline);
        pass.set_bind_group(0, &self.bind_group, &[]);
        pass.set_vertex_buffer(0, self.instance_buffer.slice(..));
        pass.draw(0..6, 0..count as u32);
    }

    pub fn draw_with_scissor(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        encoder: &mut wgpu::CommandEncoder,
        view: &wgpu::TextureView,
        depth_view: &wgpu::TextureView,
        width: u32,
        height: u32,
        instances: &[GlyphInstance],
        scissor: Option<(u32, u32, u32, u32)>,
    ) {
        let scissor = crate::renderer::types::clamp_scissor(scissor, width, height);
        if instances.is_empty() {
            return;
        }

        // Upload atlas if dirty
        if self.atlas_dirty {
            queue.write_texture(
                wgpu::TexelCopyTextureInfo {
                    texture: &self.atlas_texture, mip_level: 0,
                    origin: wgpu::Origin3d::ZERO, aspect: wgpu::TextureAspect::All,
                },
                &self.atlas_data,
                wgpu::TexelCopyBufferLayout {
                    offset: 0, bytes_per_row: Some(ATLAS_SIZE), rows_per_image: Some(ATLAS_SIZE),
                },
                wgpu::Extent3d { width: ATLAS_SIZE, height: ATLAS_SIZE, depth_or_array_layers: 1 },
            );
            let atlas_view = self.atlas_texture.create_view(&Default::default());
            self.bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
                label: Some("text_bind_group"),
                layout: &self.bind_group_layout,
                entries: &[
                    wgpu::BindGroupEntry { binding: 0, resource: self.uniform_buffer.as_entire_binding() },
                    wgpu::BindGroupEntry { binding: 1, resource: wgpu::BindingResource::TextureView(&atlas_view) },
                    wgpu::BindGroupEntry { binding: 2, resource: wgpu::BindingResource::Sampler(&self.sampler) },
                ],
            });
            self.atlas_dirty = false;
        }

        let uniforms: [f32; 4] = [width as f32, height as f32, 0.0, 0.0];
        queue.write_buffer(&self.uniform_buffer, 0, bytemuck::cast_slice(&uniforms));

        let count = instances.len().min(MAX_GLYPH_INSTANCES);
        queue.write_buffer(&self.instance_buffer, 0, bytemuck::cast_slice(&instances[..count]));

        let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
            label: Some("text_pass_scissor"),
            color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                view, resolve_target: None,
                ops: wgpu::Operations { load: wgpu::LoadOp::Load, store: wgpu::StoreOp::Store },
                depth_slice: None,
            })],
            depth_stencil_attachment: Some(wgpu::RenderPassDepthStencilAttachment {
                view: depth_view,
                depth_ops: Some(wgpu::Operations {
                    load: wgpu::LoadOp::Load,
                    store: wgpu::StoreOp::Store,
                }),
                stencil_ops: None,
            }),
            timestamp_writes: None,
            occlusion_query_set: None, multiview_mask: None,
        });
        if let Some((sx, sy, sw, sh)) = scissor {
            pass.set_scissor_rect(sx, sy, sw, sh);
        }
        pass.set_pipeline(&self.pipeline);
        pass.set_bind_group(0, &self.bind_group, &[]);
        pass.set_vertex_buffer(0, self.instance_buffer.slice(..));
        pass.draw(0..6, 0..count as u32);
    }
}

/// Magnification scale for dock icons — pure math, easily testable.
pub fn dock_magnification(
    mouse_x: f64,
    icon_center_x: f64,
    base_size: f64,
    max_scale: f64,
    influence_radius: f64,
) -> f64 {
    let distance = (mouse_x - icon_center_x).abs();
    if distance > influence_radius {
        return base_size;
    }
    let t = 1.0 - (distance / influence_radius);
    // Cosine interpolation for smooth falloff
    let scale = 1.0 + (max_scale - 1.0) * (1.0 - (t * std::f64::consts::PI).cos()) / 2.0;
    base_size * scale
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn glyph_instance_size() {
        assert_eq!(std::mem::size_of::<GlyphInstance>(), 64);
    }

    #[test]
    fn dock_magnification_at_center() {
        let size = dock_magnification(100.0, 100.0, 48.0, 2.0, 150.0);
        // At center, distance=0, t=1, scale should be max
        assert!((size - 96.0).abs() < 0.01, "Expected ~96, got {size}");
    }

    #[test]
    fn dock_magnification_outside_radius() {
        let size = dock_magnification(300.0, 100.0, 48.0, 2.0, 150.0);
        assert_eq!(size, 48.0);
    }

    #[test]
    fn dock_magnification_at_edge() {
        let size = dock_magnification(250.0, 100.0, 48.0, 2.0, 150.0);
        // At edge of influence, should be just above base
        assert!(size >= 48.0);
        assert!(size < 96.0);
    }

    #[test]
    fn dock_magnification_symmetric() {
        let left = dock_magnification(50.0, 100.0, 48.0, 2.0, 150.0);
        let right = dock_magnification(150.0, 100.0, 48.0, 2.0, 150.0);
        assert!((left - right).abs() < 0.001);
    }
}
