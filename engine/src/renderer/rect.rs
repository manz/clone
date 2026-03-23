use crate::renderer::types::{RectInstance, Uniforms};

/// Instanced quad pipeline for solid and rounded rectangles.
pub struct RectPipeline {
    solid_pipeline: wgpu::RenderPipeline,
    sdf_pipeline: wgpu::RenderPipeline,
    uniform_buffer: wgpu::Buffer,
    uniform_bind_group: wgpu::BindGroup,
    solid_instance_buffer: wgpu::Buffer,
    solid_instance_capacity: usize,
    solid_instance_offset: usize,
    rounded_instance_buffer: wgpu::Buffer,
    rounded_instance_capacity: usize,
    rounded_instance_offset: usize,
}

const INITIAL_INSTANCE_CAPACITY: usize = 256;

impl RectPipeline {
    pub fn new(device: &wgpu::Device, surface_format: wgpu::TextureFormat) -> Self {
        // Uniform buffer
        let uniform_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("rect_uniforms"),
            size: std::mem::size_of::<Uniforms>() as u64,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        let bind_group_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("rect_bind_group_layout"),
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
            label: Some("rect_bind_group"),
            layout: &bind_group_layout,
            entries: &[wgpu::BindGroupEntry {
                binding: 0,
                resource: uniform_buffer.as_entire_binding(),
            }],
        });

        let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("rect_pipeline_layout"),
            bind_group_layouts: &[&bind_group_layout],
            immediate_size: 0,
        });

        // Instance buffer layout — each instance is a RectInstance
        let instance_layout = wgpu::VertexBufferLayout {
            array_stride: std::mem::size_of::<RectInstance>() as u64,
            step_mode: wgpu::VertexStepMode::Instance,
            attributes: &wgpu::vertex_attr_array![
                2 => Float32x4,  // rect (x, y, w, h)
                3 => Float32x4,  // color (r, g, b, a)
                4 => Float32,    // radius
                5 => Float32,    // z (depth)
                6 => Float32,    // _pad0
                7 => Float32,    // _pad1
            ],
        };

        // Solid rect pipeline
        let solid_shader =
            device.create_shader_module(wgpu::ShaderModuleDescriptor {
                label: Some("rect_shader"),
                source: wgpu::ShaderSource::Wgsl(
                    include_str!("../shaders/rect.wgsl").into(),
                ),
            });

        let solid_pipeline = Self::create_pipeline(
            device,
            &pipeline_layout,
            &solid_shader,
            &instance_layout,
            surface_format,
            "solid_rect_pipeline",
        );

        // SDF rounded rect pipeline
        let sdf_shader =
            device.create_shader_module(wgpu::ShaderModuleDescriptor {
                label: Some("sdf_roundrect_shader"),
                source: wgpu::ShaderSource::Wgsl(
                    include_str!("../shaders/sdf_roundrect.wgsl").into(),
                ),
            });

        let sdf_pipeline = Self::create_pipeline(
            device,
            &pipeline_layout,
            &sdf_shader,
            &instance_layout,
            surface_format,
            "sdf_roundrect_pipeline",
        );

        let buf_size = (INITIAL_INSTANCE_CAPACITY * std::mem::size_of::<RectInstance>()) as u64;

        let solid_instance_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("solid_rect_instances"),
            size: buf_size,
            usage: wgpu::BufferUsages::VERTEX | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        let rounded_instance_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("rounded_rect_instances"),
            size: buf_size,
            usage: wgpu::BufferUsages::VERTEX | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        Self {
            solid_pipeline,
            sdf_pipeline,
            uniform_buffer,
            uniform_bind_group,
            solid_instance_buffer,
            solid_instance_capacity: INITIAL_INSTANCE_CAPACITY,
            solid_instance_offset: 0,
            rounded_instance_buffer,
            rounded_instance_capacity: INITIAL_INSTANCE_CAPACITY,
            rounded_instance_offset: 0,
        }
    }

    /// Reset instance buffer offsets (call at the start of each surface render).
    pub fn reset_instance_offsets(&mut self) {
        self.solid_instance_offset = 0;
        self.rounded_instance_offset = 0;
    }

    fn create_pipeline(
        device: &wgpu::Device,
        layout: &wgpu::PipelineLayout,
        shader: &wgpu::ShaderModule,
        instance_layout: &wgpu::VertexBufferLayout,
        surface_format: wgpu::TextureFormat,
        label: &str,
    ) -> wgpu::RenderPipeline {
        device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some(label),
            layout: Some(layout),
            vertex: wgpu::VertexState {
                module: shader,
                entry_point: Some("vs_main"),
                compilation_options: Default::default(),
                buffers: &[instance_layout.clone()],
            },
            fragment: Some(wgpu::FragmentState {
                module: shader,
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
                strip_index_format: None,
                front_face: wgpu::FrontFace::Ccw,
                cull_mode: None,
                polygon_mode: wgpu::PolygonMode::Fill,
                unclipped_depth: false,
                conservative: false,
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
        })
    }

    pub fn draw(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        encoder: &mut wgpu::CommandEncoder,
        view: &wgpu::TextureView,
        depth_view: &wgpu::TextureView,
        width: u32,
        height: u32,
        solid_instances: &[RectInstance],
        rounded_instances: &[RectInstance],
    ) {
        self.draw_with_scissor(device, queue, encoder, view, depth_view, width, height, solid_instances, rounded_instances, None);
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
        solid_instances: &[RectInstance],
        rounded_instances: &[RectInstance],
        scissor: Option<(u32, u32, u32, u32)>,
    ) {
        let scissor = crate::renderer::types::clamp_scissor(scissor, width, height);
        let uniforms = Uniforms {
            screen_size: [width as f32, height as f32],
            _pad: [0.0; 2],
        };
        queue.write_buffer(&self.uniform_buffer, 0, bytemuck::bytes_of(&uniforms));

        // Solid and rounded use separate buffers to avoid write_buffer overwrite.
        if !solid_instances.is_empty() {
            self.ensure_solid_capacity(device, self.solid_instance_offset + solid_instances.len());
            let byte_offset = (self.solid_instance_offset * std::mem::size_of::<RectInstance>()) as u64;
            queue.write_buffer(&self.solid_instance_buffer, byte_offset, bytemuck::cast_slice(solid_instances));

            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("solid_rect_pass"),
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
            pass.set_pipeline(&self.solid_pipeline);
            pass.set_bind_group(0, &self.uniform_bind_group, &[]);
            pass.set_vertex_buffer(0, self.solid_instance_buffer.slice(..));
            let start = self.solid_instance_offset as u32;
            let end = start + solid_instances.len() as u32;
            pass.draw(0..6, start..end);
            self.solid_instance_offset += solid_instances.len();
        }

        if !rounded_instances.is_empty() {
            self.ensure_rounded_capacity(device, self.rounded_instance_offset + rounded_instances.len());
            let byte_offset = (self.rounded_instance_offset * std::mem::size_of::<RectInstance>()) as u64;
            queue.write_buffer(&self.rounded_instance_buffer, byte_offset, bytemuck::cast_slice(rounded_instances));

            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("rounded_rect_pass"),
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
            pass.set_pipeline(&self.sdf_pipeline);
            pass.set_bind_group(0, &self.uniform_bind_group, &[]);
            pass.set_vertex_buffer(0, self.rounded_instance_buffer.slice(..));
            let start = self.rounded_instance_offset as u32;
            let end = start + rounded_instances.len() as u32;
            pass.draw(0..6, start..end);
            self.rounded_instance_offset += rounded_instances.len();
        }
    }

    fn ensure_solid_capacity(&mut self, device: &wgpu::Device, needed: usize) {
        if needed <= self.solid_instance_capacity {
            return;
        }
        let new_capacity = needed.next_power_of_two();
        self.solid_instance_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("solid_rect_instances"),
            size: (new_capacity * std::mem::size_of::<RectInstance>()) as u64,
            usage: wgpu::BufferUsages::VERTEX | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });
        self.solid_instance_capacity = new_capacity;
    }

    fn ensure_rounded_capacity(&mut self, device: &wgpu::Device, needed: usize) {
        if needed <= self.rounded_instance_capacity {
            return;
        }
        let new_capacity = needed.next_power_of_two();
        self.rounded_instance_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("rounded_rect_instances"),
            size: (new_capacity * std::mem::size_of::<RectInstance>()) as u64,
            usage: wgpu::BufferUsages::VERTEX | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });
        self.rounded_instance_capacity = new_capacity;
    }
}
