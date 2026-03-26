/// Dual-Kawase blur pipeline — downsample then upsample for fast, high-quality blur.
/// Used for glassmorphism (frosted glass) effects.

const BLUR_ITERATIONS: u32 = 3; // down 3 times, up 3 times = 6 passes total

pub struct BlurPipeline {
    downsample_pipeline: wgpu::RenderPipeline,
    upsample_pipeline: wgpu::RenderPipeline,
    bind_group_layout: wgpu::BindGroupLayout,
    uniform_buffer: wgpu::Buffer,
    sampler: wgpu::Sampler,
    // Mip chain textures (created on resize)
    mip_textures: Vec<wgpu::Texture>,
    mip_views: Vec<wgpu::TextureView>,
    mip_bind_groups: Vec<wgpu::BindGroup>,
    width: u32,
    height: u32,
}

impl BlurPipeline {
    pub fn new(device: &wgpu::Device, surface_format: wgpu::TextureFormat) -> Self {
        let bind_group_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("blur_bind_group_layout"),
            entries: &[
                wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::FRAGMENT,
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
            label: Some("blur_pipeline_layout"),
            bind_group_layouts: &[Some(&bind_group_layout)],
            immediate_size: 0,
        });

        let down_shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("blur_down_shader"),
            source: wgpu::ShaderSource::Wgsl(include_str!("../shaders/blur_down.wgsl").into()),
        });

        let up_shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("blur_up_shader"),
            source: wgpu::ShaderSource::Wgsl(include_str!("../shaders/blur_up.wgsl").into()),
        });

        let downsample_pipeline = Self::create_fullscreen_pipeline(
            device,
            &pipeline_layout,
            &down_shader,
            surface_format,
            "blur_down_pipeline",
        );

        let upsample_pipeline = Self::create_fullscreen_pipeline(
            device,
            &pipeline_layout,
            &up_shader,
            surface_format,
            "blur_up_pipeline",
        );

        let uniform_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("blur_uniforms"),
            size: 16,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        let sampler = device.create_sampler(&wgpu::SamplerDescriptor {
            label: Some("blur_sampler"),
            mag_filter: wgpu::FilterMode::Linear,
            min_filter: wgpu::FilterMode::Linear,
            address_mode_u: wgpu::AddressMode::ClampToEdge,
            address_mode_v: wgpu::AddressMode::ClampToEdge,
            ..Default::default()
        });

        Self {
            downsample_pipeline,
            upsample_pipeline,
            bind_group_layout,
            uniform_buffer,
            sampler,
            mip_textures: Vec::new(),
            mip_views: Vec::new(),
            mip_bind_groups: Vec::new(),
            width: 0,
            height: 0,
        }
    }

    fn create_fullscreen_pipeline(
        device: &wgpu::Device,
        layout: &wgpu::PipelineLayout,
        shader: &wgpu::ShaderModule,
        format: wgpu::TextureFormat,
        label: &str,
    ) -> wgpu::RenderPipeline {
        device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some(label),
            layout: Some(layout),
            vertex: wgpu::VertexState {
                module: shader,
                entry_point: Some("vs_main"),
                compilation_options: Default::default(),
                buffers: &[],
            },
            fragment: Some(wgpu::FragmentState {
                module: shader,
                entry_point: Some("fs_main"),
                compilation_options: Default::default(),
                targets: &[Some(wgpu::ColorTargetState {
                    format,
                    blend: None,
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
        })
    }

    /// Resize the mip chain if the surface size changed.
    pub fn resize(
        &mut self,
        device: &wgpu::Device,
        width: u32,
        height: u32,
        surface_format: wgpu::TextureFormat,
    ) {
        if width == self.width && height == self.height {
            return;
        }
        self.width = width;
        self.height = height;

        self.mip_textures.clear();
        self.mip_views.clear();
        self.mip_bind_groups.clear();

        // Create BLUR_ITERATIONS + 1 mip levels (original + downsampled)
        let mut w = width;
        let mut h = height;
        for i in 0..=BLUR_ITERATIONS {
            if i > 0 {
                w = (w / 2).max(1);
                h = (h / 2).max(1);
            }

            let texture = device.create_texture(&wgpu::TextureDescriptor {
                label: Some(&format!("blur_mip_{i}")),
                size: wgpu::Extent3d {
                    width: w,
                    height: h,
                    depth_or_array_layers: 1,
                },
                mip_level_count: 1,
                sample_count: 1,
                dimension: wgpu::TextureDimension::D2,
                format: surface_format,
                usage: wgpu::TextureUsages::RENDER_ATTACHMENT | wgpu::TextureUsages::TEXTURE_BINDING,
                view_formats: &[],
            });

            let view = texture.create_view(&Default::default());
            self.mip_textures.push(texture);
            self.mip_views.push(view);
        }

        // Create bind groups for each mip level (source → next level)
        for view in &self.mip_views {
            let bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
                label: Some("blur_mip_bind_group"),
                layout: &self.bind_group_layout,
                entries: &[
                    wgpu::BindGroupEntry {
                        binding: 0,
                        resource: self.uniform_buffer.as_entire_binding(),
                    },
                    wgpu::BindGroupEntry {
                        binding: 1,
                        resource: wgpu::BindingResource::TextureView(view),
                    },
                    wgpu::BindGroupEntry {
                        binding: 2,
                        resource: wgpu::BindingResource::Sampler(&self.sampler),
                    },
                ],
            });
            self.mip_bind_groups.push(bind_group);
        }
    }

    /// Run the blur: downsample chain then upsample chain.
    /// The source texture should already be copied to mip_textures[0].
    /// Returns a reference to the final blurred texture view.
    pub fn blur(
        &self,
        queue: &wgpu::Queue,
        encoder: &mut wgpu::CommandEncoder,
    ) -> Option<&wgpu::TextureView> {
        if self.mip_views.is_empty() {
            return None;
        }

        let n = BLUR_ITERATIONS as usize;

        // Downsample chain: mip[0] → mip[1] → mip[2] → mip[3]
        let mut w = self.width;
        let mut h = self.height;
        for i in 0..n {
            let texel_size: [f32; 4] = [1.0 / w as f32, 1.0 / h as f32, 0.0, 0.0];
            queue.write_buffer(&self.uniform_buffer, 0, bytemuck::cast_slice(&texel_size));

            w = (w / 2).max(1);
            h = (h / 2).max(1);

            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("blur_down_pass"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: &self.mip_views[i + 1],
                    resolve_target: None,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(wgpu::Color::BLACK),
                        store: wgpu::StoreOp::Store,
                    },
                    depth_slice: None,
                })],
                depth_stencil_attachment: None,
                timestamp_writes: None,
                occlusion_query_set: None,
                multiview_mask: None,
            });
            pass.set_pipeline(&self.downsample_pipeline);
            pass.set_bind_group(0, &self.mip_bind_groups[i], &[]);
            pass.draw(0..6, 0..1);
        }

        // Upsample chain: mip[3] → mip[2] → mip[1] → mip[0]
        for i in (0..n).rev() {
            let src_w = (self.width >> (i + 1) as u32).max(1);
            let src_h = (self.height >> (i + 1) as u32).max(1);
            let texel_size: [f32; 4] = [1.0 / src_w as f32, 1.0 / src_h as f32, 0.0, 0.0];
            queue.write_buffer(&self.uniform_buffer, 0, bytemuck::cast_slice(&texel_size));

            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("blur_up_pass"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: &self.mip_views[i],
                    resolve_target: None,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(wgpu::Color::BLACK),
                        store: wgpu::StoreOp::Store,
                    },
                    depth_slice: None,
                })],
                depth_stencil_attachment: None,
                timestamp_writes: None,
                occlusion_query_set: None,
                multiview_mask: None,
            });
            pass.set_pipeline(&self.upsample_pipeline);
            pass.set_bind_group(0, &self.mip_bind_groups[i + 1], &[]);
            pass.draw(0..6, 0..1);
        }

        Some(&self.mip_views[0])
    }

    /// Get the first mip texture (for copying the scene into before blurring).
    pub fn scene_texture(&self) -> Option<&wgpu::Texture> {
        self.mip_textures.first()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn blur_iterations_count() {
        assert_eq!(BLUR_ITERATIONS, 3);
    }
}
