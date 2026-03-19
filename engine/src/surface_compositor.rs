use std::collections::HashMap;

use crate::commands::RenderCommand;
use crate::renderer::DesktopRenderer;

/// An offscreen surface for a single window.
pub struct WindowSurface {
    pub texture: wgpu::Texture,
    pub view: wgpu::TextureView,
    pub width: u32,
    pub height: u32,
}

impl WindowSurface {
    pub fn new(device: &wgpu::Device, format: wgpu::TextureFormat, width: u32, height: u32) -> Self {
        let texture = device.create_texture(&wgpu::TextureDescriptor {
            label: Some("window_surface"),
            size: wgpu::Extent3d {
                width: width.max(1),
                height: height.max(1),
                depth_or_array_layers: 1,
            },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format,
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT | wgpu::TextureUsages::TEXTURE_BINDING,
            view_formats: &[],
        });
        let view = texture.create_view(&Default::default());
        Self { texture, view, width, height }
    }

    pub fn resize(&mut self, device: &wgpu::Device, format: wgpu::TextureFormat, width: u32, height: u32) {
        if self.width == width && self.height == height {
            return;
        }
        *self = Self::new(device, format, width, height);
    }
}

/// Describes a window for composition.
pub struct CompositeWindow {
    pub surface_id: u64,
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
    pub corner_radius: f32,
    pub opacity: f32,
}

/// GPU instance for the compositor shader.
#[repr(C)]
#[derive(Copy, Clone, bytemuck::Pod, bytemuck::Zeroable)]
struct CompositeInstance {
    rect: [f32; 4],
    corner_radius: f32,
    opacity: f32,
    _pad: [f32; 2],
}

/// Manages per-window offscreen textures and composites them onto the screen.
pub struct SurfaceCompositor {
    surfaces: HashMap<u64, WindowSurface>,
    pipeline: wgpu::RenderPipeline,
    bind_group_layout: wgpu::BindGroupLayout,
    uniform_buffer: wgpu::Buffer,
    instance_buffer: wgpu::Buffer,
    sampler: wgpu::Sampler,
    surface_format: wgpu::TextureFormat,
}

impl SurfaceCompositor {
    pub fn new(device: &wgpu::Device, surface_format: wgpu::TextureFormat) -> Self {
        let bind_group_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("compositor_bgl"),
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

        let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("compositor_pl"),
            bind_group_layouts: &[&bind_group_layout],
            immediate_size: 0,
        });

        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("composite_window"),
            source: wgpu::ShaderSource::Wgsl(
                include_str!("shaders/composite_window.wgsl").into(),
            ),
        });

        let instance_layout = wgpu::VertexBufferLayout {
            array_stride: std::mem::size_of::<CompositeInstance>() as u64,
            step_mode: wgpu::VertexStepMode::Instance,
            attributes: &wgpu::vertex_attr_array![
                0 => Float32x4, // rect
                1 => Float32,   // corner_radius
                2 => Float32,   // opacity
                3 => Float32,   // _pad0
                4 => Float32,   // _pad1
            ],
        };

        let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("compositor_pipeline"),
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
            depth_stencil: None,
            multisample: wgpu::MultisampleState::default(),
            multiview_mask: None,
            cache: None,
        });

        let uniform_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("compositor_uniforms"),
            size: 16,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        let instance_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("compositor_instances"),
            size: std::mem::size_of::<CompositeInstance>() as u64,
            usage: wgpu::BufferUsages::VERTEX | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        let sampler = device.create_sampler(&wgpu::SamplerDescriptor {
            label: Some("compositor_sampler"),
            mag_filter: wgpu::FilterMode::Linear,
            min_filter: wgpu::FilterMode::Linear,
            ..Default::default()
        });

        Self {
            surfaces: HashMap::new(),
            pipeline,
            bind_group_layout,
            uniform_buffer,
            instance_buffer,
            sampler,
            surface_format,
        }
    }

    /// Ensure a surface exists for a given ID at the given physical size.
    pub fn ensure_surface(&mut self, device: &wgpu::Device, surface_id: u64, width: u32, height: u32) {
        let entry = self.surfaces.entry(surface_id).or_insert_with(|| {
            WindowSurface::new(device, self.surface_format, width, height)
        });
        entry.resize(device, self.surface_format, width, height);
    }

    /// Get the texture view for a surface to render into.
    pub fn surface_view(&self, surface_id: u64) -> Option<&wgpu::TextureView> {
        self.surfaces.get(&surface_id).map(|s| &s.view)
    }

    /// Remove surfaces not in the active set.
    pub fn gc(&mut self, active_ids: &[u64]) {
        self.surfaces.retain(|id, _| active_ids.contains(id));
    }

    /// Render commands into a window's offscreen surface.
    pub fn render_to_surface(
        &self,
        surface_id: u64,
        renderer: &mut DesktopRenderer,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        commands: &[RenderCommand],
        scale: f32,
    ) {
        let Some(surface) = self.surfaces.get(&surface_id) else { return };

        let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
            label: Some("window_render"),
        });

        renderer.render(
            device, queue, &mut encoder, &surface.view,
            commands, surface.width, surface.height, scale,
        );

        queue.submit([encoder.finish()]);
    }

    /// Composite all windows onto the screen surface, back-to-front.
    pub fn composite(
        &self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        encoder: &mut wgpu::CommandEncoder,
        screen_view: &wgpu::TextureView,
        screen_width: u32,
        screen_height: u32,
        windows: &[CompositeWindow],
    ) {
        let uniforms: [f32; 4] = [screen_width as f32, screen_height as f32, 0.0, 0.0];
        queue.write_buffer(&self.uniform_buffer, 0, bytemuck::cast_slice(&uniforms));

        // Draw each window as a textured quad, one at a time (separate bind group per texture)
        for win in windows {
            let Some(surface) = self.surfaces.get(&win.surface_id) else { continue };

            let bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
                label: Some("compositor_bg"),
                layout: &self.bind_group_layout,
                entries: &[
                    wgpu::BindGroupEntry {
                        binding: 0,
                        resource: self.uniform_buffer.as_entire_binding(),
                    },
                    wgpu::BindGroupEntry {
                        binding: 1,
                        resource: wgpu::BindingResource::TextureView(&surface.view),
                    },
                    wgpu::BindGroupEntry {
                        binding: 2,
                        resource: wgpu::BindingResource::Sampler(&self.sampler),
                    },
                ],
            });

            let instance = CompositeInstance {
                rect: [win.x, win.y, win.width, win.height],
                corner_radius: win.corner_radius,
                opacity: win.opacity,
                _pad: [0.0; 2],
            };
            queue.write_buffer(&self.instance_buffer, 0, bytemuck::bytes_of(&instance));

            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("composite_pass"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: screen_view,
                    resolve_target: None,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Load,
                        store: wgpu::StoreOp::Store,
                    },
                    depth_slice: None,
                })],
                depth_stencil_attachment: None,
                timestamp_writes: None,
                occlusion_query_set: None,
                multiview_mask: None,
            });

            pass.set_pipeline(&self.pipeline);
            pass.set_bind_group(0, &bind_group, &[]);
            pass.set_vertex_buffer(0, self.instance_buffer.slice(..));
            pass.draw(0..6, 0..1);
        }
    }
}
