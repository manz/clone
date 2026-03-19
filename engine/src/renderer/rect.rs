use crate::renderer::types::{RectInstance, Uniforms};

/// Instanced quad pipeline for solid and rounded rectangles.
pub struct RectPipeline {
    solid_pipeline: wgpu::RenderPipeline,
    sdf_pipeline: wgpu::RenderPipeline,
    uniform_buffer: wgpu::Buffer,
    uniform_bind_group: wgpu::BindGroup,
    instance_buffer: wgpu::Buffer,
    instance_capacity: usize,
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
                5 => Float32,    // _pad0
                6 => Float32,    // _pad1
                7 => Float32,    // _pad2
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

        // Instance buffer
        let instance_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("rect_instances"),
            size: (INITIAL_INSTANCE_CAPACITY * std::mem::size_of::<RectInstance>()) as u64,
            usage: wgpu::BufferUsages::VERTEX | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        Self {
            solid_pipeline,
            sdf_pipeline,
            uniform_buffer,
            uniform_bind_group,
            instance_buffer,
            instance_capacity: INITIAL_INSTANCE_CAPACITY,
        }
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
            depth_stencil: None,
            multisample: wgpu::MultisampleState::default(),
            multiview_mask: None,
            cache: None,
        })
    }

    /// Upload uniforms and instances, then draw.
    pub fn draw(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        encoder: &mut wgpu::CommandEncoder,
        view: &wgpu::TextureView,
        width: u32,
        height: u32,
        solid_instances: &[RectInstance],
        rounded_instances: &[RectInstance],
    ) {
        // Update uniforms
        let uniforms = Uniforms {
            screen_size: [width as f32, height as f32],
            _pad: [0.0; 2],
        };
        queue.write_buffer(&self.uniform_buffer, 0, bytemuck::bytes_of(&uniforms));

        // Draw solid rects
        if !solid_instances.is_empty() {
            self.ensure_instance_capacity(device, solid_instances.len());
            queue.write_buffer(
                &self.instance_buffer,
                0,
                bytemuck::cast_slice(solid_instances),
            );

            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("solid_rect_pass"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view,
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
            pass.set_pipeline(&self.solid_pipeline);
            pass.set_bind_group(0, &self.uniform_bind_group, &[]);
            pass.set_vertex_buffer(0, self.instance_buffer.slice(..));
            pass.draw(0..6, 0..solid_instances.len() as u32);
        }

        // Draw rounded rects
        if !rounded_instances.is_empty() {
            self.ensure_instance_capacity(device, rounded_instances.len());
            queue.write_buffer(
                &self.instance_buffer,
                0,
                bytemuck::cast_slice(rounded_instances),
            );

            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("rounded_rect_pass"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view,
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
            pass.set_pipeline(&self.sdf_pipeline);
            pass.set_bind_group(0, &self.uniform_bind_group, &[]);
            pass.set_vertex_buffer(0, self.instance_buffer.slice(..));
            pass.draw(0..6, 0..rounded_instances.len() as u32);
        }
    }

    fn ensure_instance_capacity(&mut self, device: &wgpu::Device, needed: usize) {
        if needed <= self.instance_capacity {
            return;
        }
        let new_capacity = needed.next_power_of_two();
        self.instance_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("rect_instances"),
            size: (new_capacity * std::mem::size_of::<RectInstance>()) as u64,
            usage: wgpu::BufferUsages::VERTEX | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });
        self.instance_capacity = new_capacity;
    }
}
