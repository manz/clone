use std::collections::HashMap;

use include_dir::{include_dir, Dir};
use resvg::tiny_skia;
use resvg::usvg;

use crate::commands::{IconStyle, RgbaColor};
use crate::renderer::types::Uniforms;

/// Embedded Phosphor SVG directories.
static ICONS_DIR: Dir = include_dir!("$CARGO_MANIFEST_DIR/assets/phosphor-icons/SVGs");

/// Cache key for a rasterized icon texture.
#[derive(Clone, Debug, PartialEq, Eq, Hash)]
struct IconCacheKey {
    name: String,
    style: IconStyleKey,
    /// Pixel size (after DPI scaling) — icons are square.
    size_px: u32,
    /// Color as 4 bytes for hashing.
    color_rgba: [u8; 4],
}

/// Hashable version of IconStyle.
#[derive(Clone, Debug, PartialEq, Eq, Hash)]
enum IconStyleKey {
    Regular,
    Fill,
    Duotone,
    Thin,
    Light,
    Bold,
}

impl From<&IconStyle> for IconStyleKey {
    fn from(s: &IconStyle) -> Self {
        match s {
            IconStyle::Regular => Self::Regular,
            IconStyle::Fill => Self::Fill,
            IconStyle::Duotone => Self::Duotone,
            IconStyle::Thin => Self::Thin,
            IconStyle::Light => Self::Light,
            IconStyle::Bold => Self::Bold,
        }
    }
}

/// GPU-side cached icon texture with its bind group.
struct CachedIcon {
    bind_group: wgpu::BindGroup,
    #[allow(dead_code)]
    texture: wgpu::Texture,
}

/// GPU instance for one icon draw.
#[repr(C)]
#[derive(Copy, Clone, Debug, bytemuck::Pod, bytemuck::Zeroable)]
pub struct IconInstance {
    pub rect: [f32; 4], // x, y, w, h
    pub z: f32,
    pub _pad: [f32; 3],
}

pub struct IconPipeline {
    pipeline: wgpu::RenderPipeline,
    uniform_buffer: wgpu::Buffer,
    uniform_bind_group: wgpu::BindGroup,
    texture_bind_group_layout: wgpu::BindGroupLayout,
    sampler: wgpu::Sampler,
    instance_buffer: wgpu::Buffer,
    instance_capacity: usize,
    instance_offset: usize,
    cache: HashMap<IconCacheKey, CachedIcon>,
}

impl IconPipeline {
    pub fn new(device: &wgpu::Device, surface_format: wgpu::TextureFormat) -> Self {
        // Uniform bind group (group 0)
        let uniform_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("icon_uniforms"),
            size: std::mem::size_of::<Uniforms>() as u64,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        let uniform_bind_group_layout =
            device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                label: Some("icon_uniform_layout"),
                entries: &[wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::VERTEX,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                    count: None,
                }],
            });

        let uniform_bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("icon_uniform_bg"),
            layout: &uniform_bind_group_layout,
            entries: &[wgpu::BindGroupEntry {
                binding: 0,
                resource: uniform_buffer.as_entire_binding(),
            }],
        });

        // Texture bind group layout (group 1) — per-icon
        let texture_bind_group_layout =
            device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                label: Some("icon_texture_layout"),
                entries: &[
                    wgpu::BindGroupLayoutEntry {
                        binding: 0,
                        visibility: wgpu::ShaderStages::FRAGMENT,
                        ty: wgpu::BindingType::Texture {
                            multisampled: false,
                            view_dimension: wgpu::TextureViewDimension::D2,
                            sample_type: wgpu::TextureSampleType::Float { filterable: true },
                        },
                        count: None,
                    },
                    wgpu::BindGroupLayoutEntry {
                        binding: 1,
                        visibility: wgpu::ShaderStages::FRAGMENT,
                        ty: wgpu::BindingType::Sampler(wgpu::SamplerBindingType::Filtering),
                        count: None,
                    },
                ],
            });

        let sampler = device.create_sampler(&wgpu::SamplerDescriptor {
            label: Some("icon_sampler"),
            mag_filter: wgpu::FilterMode::Linear,
            min_filter: wgpu::FilterMode::Linear,
            ..Default::default()
        });

        let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("icon_pipeline_layout"),
            bind_group_layouts: &[&uniform_bind_group_layout, &texture_bind_group_layout],
            immediate_size: 0,
        });

        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("icon_shader"),
            source: wgpu::ShaderSource::Wgsl(include_str!("../shaders/icon.wgsl").into()),
        });

        let instance_layout = wgpu::VertexBufferLayout {
            array_stride: std::mem::size_of::<IconInstance>() as u64,
            step_mode: wgpu::VertexStepMode::Instance,
            attributes: &wgpu::vertex_attr_array![
                0 => Float32x4,  // rect
                1 => Float32,    // z
                2 => Float32,    // _pad0
                3 => Float32,    // _pad1
                4 => Float32,    // _pad2
            ],
        };

        let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("icon_pipeline"),
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
            label: Some("icon_instances"),
            size: (64 * std::mem::size_of::<IconInstance>()) as u64,
            usage: wgpu::BufferUsages::VERTEX | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        Self {
            pipeline,
            uniform_buffer,
            uniform_bind_group,
            texture_bind_group_layout,
            sampler,
            instance_buffer,
            instance_capacity: 64,
            instance_offset: 0,
            cache: HashMap::new(),
        }
    }

    /// Reset instance offset (call at the start of each surface render).
    pub fn reset_instance_offset(&mut self) {
        self.instance_offset = 0;
    }

    /// Draw a single icon. Looks up/rasterizes the SVG, caches the GPU texture, draws.
    pub fn draw_icon(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        encoder: &mut wgpu::CommandEncoder,
        view: &wgpu::TextureView,
        depth_view: &wgpu::TextureView,
        screen_width: u32,
        screen_height: u32,
        name: &str,
        style: &IconStyle,
        x: f32,
        y: f32,
        w: f32,
        h: f32,
        color: &RgbaColor,
        z: f32,
        scissor: Option<(u32, u32, u32, u32)>,
    ) {
        let size_px = w.max(h).ceil() as u32;
        if size_px == 0 {
            return;
        }

        let color_rgba = [
            (color.r * 255.0) as u8,
            (color.g * 255.0) as u8,
            (color.b * 255.0) as u8,
            (color.a * 255.0) as u8,
        ];

        let key = IconCacheKey {
            name: name.to_string(),
            style: IconStyleKey::from(style),
            size_px,
            color_rgba,
        };

        // Ensure texture is cached
        if !self.cache.contains_key(&key) {
            if let Some(rgba) = rasterize_icon(name, style, size_px, color) {
                let texture = device.create_texture(&wgpu::TextureDescriptor {
                    label: Some("icon_tex"),
                    size: wgpu::Extent3d {
                        width: size_px,
                        height: size_px,
                        depth_or_array_layers: 1,
                    },
                    mip_level_count: 1,
                    sample_count: 1,
                    dimension: wgpu::TextureDimension::D2,
                    format: wgpu::TextureFormat::Rgba8Unorm,
                    usage: wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_DST,
                    view_formats: &[],
                });

                queue.write_texture(
                    wgpu::TexelCopyTextureInfo {
                        texture: &texture,
                        mip_level: 0,
                        origin: wgpu::Origin3d::ZERO,
                        aspect: wgpu::TextureAspect::All,
                    },
                    &rgba,
                    wgpu::TexelCopyBufferLayout {
                        offset: 0,
                        bytes_per_row: Some(4 * size_px),
                        rows_per_image: Some(size_px),
                    },
                    wgpu::Extent3d {
                        width: size_px,
                        height: size_px,
                        depth_or_array_layers: 1,
                    },
                );

                let tex_view = texture.create_view(&wgpu::TextureViewDescriptor::default());
                let bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
                    label: Some("icon_tex_bg"),
                    layout: &self.texture_bind_group_layout,
                    entries: &[
                        wgpu::BindGroupEntry {
                            binding: 0,
                            resource: wgpu::BindingResource::TextureView(&tex_view),
                        },
                        wgpu::BindGroupEntry {
                            binding: 1,
                            resource: wgpu::BindingResource::Sampler(&self.sampler),
                        },
                    ],
                });

                self.cache.insert(key.clone(), CachedIcon { bind_group, texture });
            } else {
                return; // SVG not found
            }
        }

        // Upload instance at unique offset to avoid write_buffer clobbering
        let instance = IconInstance {
            rect: [x, y, w, h],
            z,
            _pad: [0.0; 3],
        };

        let slot = self.instance_offset;
        self.instance_offset += 1;
        self.ensure_capacity(device, self.instance_offset);
        let byte_offset = (slot * std::mem::size_of::<IconInstance>()) as u64;
        queue.write_buffer(&self.instance_buffer, byte_offset, bytemuck::bytes_of(&instance));

        let cached = self.cache.get(&key).unwrap();

        // Update uniforms
        let uniforms = Uniforms {
            screen_size: [screen_width as f32, screen_height as f32],
            _pad: [0.0; 2],
        };
        queue.write_buffer(&self.uniform_buffer, 0, bytemuck::bytes_of(&uniforms));

        // Draw
        let scissor =
            crate::renderer::types::clamp_scissor(scissor, screen_width, screen_height);

        let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
            label: Some("icon_pass"),
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
        if let Some((sx, sy, sw, sh)) = scissor {
            pass.set_scissor_rect(sx, sy, sw, sh);
        }
        pass.set_pipeline(&self.pipeline);
        pass.set_bind_group(0, &self.uniform_bind_group, &[]);
        pass.set_bind_group(1, &cached.bind_group, &[]);
        pass.set_vertex_buffer(0, self.instance_buffer.slice(..));
        pass.draw(0..6, (slot as u32)..(slot as u32 + 1));
    }

    fn ensure_capacity(&mut self, device: &wgpu::Device, needed: usize) {
        if needed <= self.instance_capacity {
            return;
        }
        let new_cap = needed.next_power_of_two();
        self.instance_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("icon_instances"),
            size: (new_cap * std::mem::size_of::<IconInstance>()) as u64,
            usage: wgpu::BufferUsages::VERTEX | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });
        self.instance_capacity = new_cap;
    }
}

/// Map IconStyle to the SVG subdirectory name.
fn style_dir(style: &IconStyle) -> &'static str {
    match style {
        IconStyle::Regular => "regular",
        IconStyle::Fill => "fill",
        IconStyle::Duotone => "duotone",
        IconStyle::Thin => "thin",
        IconStyle::Light => "light",
        IconStyle::Bold => "bold",
    }
}

/// Map IconStyle to the SVG filename suffix.
fn style_suffix(style: &IconStyle) -> &'static str {
    match style {
        IconStyle::Regular => "",
        IconStyle::Fill => "-fill",
        IconStyle::Duotone => "-duotone",
        IconStyle::Thin => "-thin",
        IconStyle::Light => "-light",
        IconStyle::Bold => "-bold",
    }
}

/// Load and rasterize a Phosphor SVG icon at the given pixel size with tint color.
/// Returns RGBA pixel data (size_px × size_px).
fn rasterize_icon(name: &str, style: &IconStyle, size_px: u32, color: &RgbaColor) -> Option<Vec<u8>> {
    let dir = style_dir(style);
    let suffix = style_suffix(style);
    let filename = format!("{}{}.svg", name, suffix);
    let path = format!("{}/{}", dir, filename);

    let svg_data = ICONS_DIR.get_file(&path)?;
    let svg_bytes = svg_data.contents();

    // Parse and apply tint color by replacing stroke/fill with the requested color
    let svg_str = std::str::from_utf8(svg_bytes).ok()?;
    let hex_color = format!(
        "#{:02x}{:02x}{:02x}",
        (color.r * 255.0) as u8,
        (color.g * 255.0) as u8,
        (color.b * 255.0) as u8,
    );

    // Replace currentColor and black (#000) with the tint color
    let tinted = svg_str
        .replace("currentColor", &hex_color)
        .replace("\"#000\"", &format!("\"{}\"", hex_color))
        .replace("\"#000000\"", &format!("\"{}\"", hex_color))
        .replace("\"black\"", &format!("\"{}\"", hex_color));

    let opts = usvg::Options::default();
    let tree = usvg::Tree::from_str(&tinted, &opts).ok()?;

    let mut pixmap = tiny_skia::Pixmap::new(size_px, size_px)?;

    // Phosphor SVGs are 256×256 — scale to requested size
    let sx = size_px as f32 / 256.0;
    let sy = size_px as f32 / 256.0;
    let transform = tiny_skia::Transform::from_scale(sx, sy);

    resvg::render(&tree, transform, &mut pixmap.as_mut());

    // Apply alpha from color
    if color.a < 1.0 {
        let alpha = color.a;
        let data = pixmap.data_mut();
        for pixel in data.chunks_exact_mut(4) {
            pixel[3] = (pixel[3] as f32 * alpha) as u8;
            // Premultiplied alpha correction
            pixel[0] = (pixel[0] as f32 * alpha) as u8;
            pixel[1] = (pixel[1] as f32 * alpha) as u8;
            pixel[2] = (pixel[2] as f32 * alpha) as u8;
        }
    }

    Some(pixmap.take())
}
