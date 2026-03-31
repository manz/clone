use std::collections::HashMap;

use crate::commands::RenderCommand;
use crate::renderer::DesktopRenderer;
use wgpu_shared_surface::SharedTexture;

/// An offscreen surface for a single window.
pub struct WindowSurface {
    pub texture: wgpu::Texture,
    pub view: wgpu::TextureView,
    pub depth_texture: wgpu::Texture,
    pub depth_view: wgpu::TextureView,
    pub width: u32,
    pub height: u32,
    /// Size of the last rendered content (may lag behind width/height during resize).
    /// Used for stretching: UV mapping samples (0,0)-(content_width/width, content_height/height).
    pub content_width: u32,
    pub content_height: u32,
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
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT | wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_SRC | wgpu::TextureUsages::COPY_DST,
            view_formats: &[],
        });
        let view = texture.create_view(&Default::default());
        let depth_texture = device.create_texture(&wgpu::TextureDescriptor {
            label: Some("window_depth"),
            size: wgpu::Extent3d {
                width: width.max(1),
                height: height.max(1),
                depth_or_array_layers: 1,
            },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: wgpu::TextureFormat::Depth32Float,
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
            view_formats: &[],
        });
        let depth_view = depth_texture.create_view(&Default::default());
        Self { texture, view, depth_texture, depth_view, width, height, content_width: width, content_height: height }
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
    /// Expected physical content size — may differ from texture size
    /// when the IOSurface was allocated larger than current content.
    pub content_width: f32,
    pub content_height: f32,
}

/// GPU instance for the compositor shader.
#[repr(C)]
#[derive(Copy, Clone, bytemuck::Pod, bytemuck::Zeroable)]
struct CompositeInstance {
    rect: [f32; 4],
    corner_radius: f32,
    opacity: f32,
    shadow_expand: f32,
    /// Max U coordinate for content region (content may be smaller than texture).
    content_u_max: f32,
    /// Max V coordinate for content region.
    content_v_max: f32,
    _pad: [f32; 3],
}

/// Manages per-window offscreen textures and composites them onto the screen.
pub struct SurfaceCompositor {
    surfaces: HashMap<u64, WindowSurface>,
    /// Tracks which surface_id → iosurface_id mapping is active, to avoid reimporting.
    #[cfg(target_os = "macos")]
    imported_iosurfaces: HashMap<u64, u32>,
    pipeline: wgpu::RenderPipeline,
    bind_group_layout: wgpu::BindGroupLayout,
    uniform_buffer: wgpu::Buffer,
    instance_buffer: wgpu::Buffer,
    sampler: wgpu::Sampler,
    offscreen_format: wgpu::TextureFormat,
}

impl SurfaceCompositor {
    /// Create a compositor.
    /// - `offscreen_format`: format for per-window offscreen textures (linear)
    /// - `screen_format`: format for the composite pipeline output (sRGB)
    pub fn new(device: &wgpu::Device, offscreen_format: wgpu::TextureFormat, screen_format: wgpu::TextureFormat) -> Self {
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
            bind_group_layouts: &[Some(&bind_group_layout)],
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
                3 => Float32,   // shadow_expand
                4 => Float32,   // content_u_max
                5 => Float32,   // content_v_max
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
                    format: screen_format,
                    blend: Some(wgpu::BlendState::PREMULTIPLIED_ALPHA_BLENDING),
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
            #[cfg(target_os = "macos")]
            imported_iosurfaces: HashMap::new(),
            pipeline,
            bind_group_layout,
            uniform_buffer,
            instance_buffer,
            sampler,
            offscreen_format,
        }
    }

    /// Ensure a surface exists for a given ID at the given physical size.
    pub fn ensure_surface(&mut self, device: &wgpu::Device, surface_id: u64, width: u32, height: u32) {
        let entry = self.surfaces.entry(surface_id).or_insert_with(|| {
            WindowSurface::new(device, self.offscreen_format, width, height)
        });
        entry.resize(device, self.offscreen_format, width, height);
    }

    /// Get the texture view for a surface to render into.
    pub fn surface_view(&self, surface_id: u64) -> Option<&wgpu::TextureView> {
        self.surfaces.get(&surface_id).map(|s| &s.view)
    }

    /// Import a shared surface by its platform ID (IOSurface ID on macOS).
    /// Caches the import — only reimports when the surface ID changes.
    pub fn import_shared_surface(
        &mut self,
        device: &wgpu::Device,
        surface_id: u64,
        platform_id: u32,
        _width_hint: u32,
        _height_hint: u32,
    ) -> bool {
        #[cfg(target_os = "macos")]
        {
            // Skip if already imported with the same platform ID
            if self.imported_iosurfaces.get(&surface_id) == Some(&platform_id) {
                return true;
            }

            // Get actual dimensions from the IOSurface
            let raw = wgpu_shared_surface::iosurface_lookup(platform_id);
            if raw.is_null() {
                log::error!("IOSurfaceLookup({platform_id}) failed for surface {surface_id}");
                return false;
            }
            let width = unsafe { wgpu_shared_surface::iosurface_get_width(raw) } as u32;
            let height = unsafe { wgpu_shared_surface::iosurface_get_height(raw) } as u32;
            wgpu_shared_surface::iosurface_release(raw);

            match SharedTexture::from_id(device, platform_id, width, height, self.offscreen_format) {
                Ok(shared) => {
                    let view = shared.texture().create_view(&Default::default());
                    let depth_texture = device.create_texture(&wgpu::TextureDescriptor {
                        label: Some("imported_depth"),
                        size: wgpu::Extent3d { width, height, depth_or_array_layers: 1 },
                        mip_level_count: 1,
                        sample_count: 1,
                        dimension: wgpu::TextureDimension::D2,
                        format: wgpu::TextureFormat::Depth32Float,
                        usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
                        view_formats: &[],
                    });
                    let depth_view = depth_texture.create_view(&Default::default());
                    self.surfaces.insert(surface_id, WindowSurface {
                        texture: shared.into_texture(),
                        view,
                        depth_texture,
                        depth_view,
                        width,
                        height,
                        content_width: width,
                        content_height: height,
                    });
                    self.imported_iosurfaces.insert(surface_id, platform_id);
                    true
                }
                Err(e) => {
                    log::error!("Failed to import surface {platform_id} for {surface_id}: {e}");
                    false
                }
            }
        }
        #[cfg(not(target_os = "macos"))]
        {
            // Linux: DMA-BUF import not done via platform_id — use import_shared_surface_fd
            let _ = (device, surface_id, platform_id, _width_hint, _height_hint);
            false
        }
    }

    /// Import a shared surface from a DMA-BUF file descriptor (Linux).
    /// The fd is dup'd internally — caller keeps ownership.
    #[cfg(not(target_os = "macos"))]
    pub fn import_shared_surface_fd(
        &mut self,
        device: &wgpu::Device,
        surface_id: u64,
        fd: i32,
        width: u32,
        height: u32,
    ) -> bool {
        match SharedTexture::from_fd(device, fd, width, height, self.offscreen_format) {
            Ok(shared) => {
                let view = shared.texture().create_view(&Default::default());
                let depth_texture = device.create_texture(&wgpu::TextureDescriptor {
                    label: Some("imported_depth"),
                    size: wgpu::Extent3d { width, height, depth_or_array_layers: 1 },
                    mip_level_count: 1,
                    sample_count: 1,
                    dimension: wgpu::TextureDimension::D2,
                    format: wgpu::TextureFormat::Depth32Float,
                    usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
                    view_formats: &[],
                });
                let depth_view = depth_texture.create_view(&Default::default());
                self.surfaces.insert(surface_id, WindowSurface {
                    texture: shared.into_texture(),
                    view,
                    depth_texture,
                    depth_view,
                    width,
                    height,
                    content_width: width,
                    content_height: height,
                });
                true
            }
            Err(e) => {
                log::error!("Failed to import DMA-BUF fd {fd} for surface {surface_id}: {e}");
                false
            }
        }
    }

    /// Remove surfaces not in the active set.
    pub fn gc(&mut self, active_ids: &[u64]) {
        self.surfaces.retain(|id, _| active_ids.contains(id));
        #[cfg(target_os = "macos")]
        self.imported_iosurfaces.retain(|id, _| active_ids.contains(id));
    }

    /// Dump a surface texture to a PNG file for debugging.
    pub fn dump_surface(&self, surface_id: u64, device: &wgpu::Device, queue: &wgpu::Queue, path: &str) {
        let Some(surface) = self.surfaces.get(&surface_id) else { return };
        let width = surface.width;
        let height = surface.height;
        let bytes_per_row = (width * 4 + 255) & !255; // align to 256
        let buffer_size = (bytes_per_row * height) as u64;

        let staging = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("texture_readback"),
            size: buffer_size,
            usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
            mapped_at_creation: false,
        });

        let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
            label: Some("readback_encoder"),
        });
        encoder.copy_texture_to_buffer(
            wgpu::TexelCopyTextureInfo {
                texture: &surface.texture,
                mip_level: 0,
                origin: wgpu::Origin3d::ZERO,
                aspect: wgpu::TextureAspect::All,
            },
            wgpu::TexelCopyBufferInfo {
                buffer: &staging,
                layout: wgpu::TexelCopyBufferLayout {
                    offset: 0,
                    bytes_per_row: Some(bytes_per_row),
                    rows_per_image: Some(height),
                },
            },
            wgpu::Extent3d { width, height, depth_or_array_layers: 1 },
        );
        queue.submit([encoder.finish()]);

        let slice = staging.slice(..);
        let (tx, rx) = std::sync::mpsc::channel();
        slice.map_async(wgpu::MapMode::Read, move |r| { let _ = tx.send(r); });
        device.poll(wgpu::PollType::wait_indefinitely()).ok();
        let _ = rx.recv();

        let data = slice.get_mapped_range();
        // Convert BGRA to RGBA for PNG
        let mut rgba = Vec::with_capacity((width * height * 4) as usize);
        for row in 0..height {
            let start = (row * bytes_per_row) as usize;
            for col in 0..width {
                let i = start + (col * 4) as usize;
                rgba.push(data[i + 2]); // R (from B)
                rgba.push(data[i + 1]); // G
                rgba.push(data[i]);     // B (from R)
                rgba.push(data[i + 3]); // A
            }
        }
        drop(data);
        staging.unmap();

        // Write PNG
        if let Ok(file) = std::fs::File::create(path) {
            let w = std::io::BufWriter::new(file);
            let mut encoder = image::codecs::png::PngEncoder::new(w);
            use image::ImageEncoder;
            let _ = encoder.write_image(&rgba, width, height, image::ExtendedColorType::Rgba8);
            eprintln!("[DUMP] Surface {} saved to {path} ({}x{})", surface_id, width, height);
        }
    }

    /// Upload pre-rendered BGRA8 pixels directly into a surface's texture.
    /// Used for app-side rendered windows where the app already produced pixels.
    pub fn upload_pixels(
        &self,
        surface_id: u64,
        queue: &wgpu::Queue,
        pixels: &[u8],
        width: u32,
        height: u32,
    ) {
        let Some(surface) = self.surfaces.get(&surface_id) else { return };
        if surface.width != width || surface.height != height { return; }
        // Validate pixel buffer matches expected size (avoids crash during resize race)
        let expected = (width * height * 4) as usize;
        if pixels.len() < expected { return; }

        queue.write_texture(
            wgpu::TexelCopyTextureInfo {
                texture: &surface.texture,
                mip_level: 0,
                origin: wgpu::Origin3d::ZERO,
                aspect: wgpu::TextureAspect::All,
            },
            pixels,
            wgpu::TexelCopyBufferLayout {
                offset: 0,
                bytes_per_row: Some(width * 4),
                rows_per_image: Some(height),
            },
            wgpu::Extent3d {
                width,
                height,
                depth_or_array_layers: 1,
            },
        );
    }

    /// Render commands into a window's offscreen surface.
    pub fn render_to_surface(
        &mut self,
        surface_id: u64,
        renderer: &mut DesktopRenderer,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        commands: &[RenderCommand],
        scale: f32,
        transparent_clear: bool,
    ) {
        let Some(surface) = self.surfaces.get_mut(&surface_id) else { return };
        // Update content size — this frame matches the rendered dimensions
        surface.content_width = surface.width;
        surface.content_height = surface.height;
        let surface = self.surfaces.get(&surface_id).unwrap();

        let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
            label: Some("window_render"),
        });

        if transparent_clear {
            renderer.render_transparent(
                device, queue, &mut encoder, &surface.view, &surface.depth_view,
                commands, surface.width, surface.height, scale,
            );
        } else {
            renderer.render(
                device, queue, &mut encoder, &surface.view, &surface.depth_view,
                commands, surface.width, surface.height, scale,
            );
        }

        queue.submit([encoder.finish()]);
    }

    /// Composite all windows onto the screen surface, back-to-front.
    /// Each window is submitted as a separate encoder to avoid buffer overwrite.
    pub fn composite(
        &self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        screen_view: &wgpu::TextureView,
        screen_width: u32,
        screen_height: u32,
        windows: &[CompositeWindow],
    ) {
        let uniforms: [f32; 4] = [screen_width as f32, screen_height as f32, 0.0, 0.0];
        queue.write_buffer(&self.uniform_buffer, 0, bytemuck::cast_slice(&uniforms));

        // Each window gets its own encoder+submit to avoid instance buffer overwrites.
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

            // Compute content UV scale: content may be smaller than texture
            // (IOSurface textures only grow, never shrink)
            let content_u_max = if win.content_width > 0.0 && surface.width > 0 {
                (win.content_width / surface.width as f32).min(1.0)
            } else {
                1.0
            };
            let content_v_max = if win.content_height > 0.0 && surface.height > 0 {
                (win.content_height / surface.height as f32).min(1.0)
            } else {
                1.0
            };

            // Expand the quad to make room for the shadow
            let shadow_expand: f32 = if win.corner_radius > 0.0 { 30.0 } else { 0.0 };
            let instance = CompositeInstance {
                rect: [
                    win.x - shadow_expand,
                    win.y - shadow_expand,
                    win.width + shadow_expand * 2.0,
                    win.height + shadow_expand * 2.0,
                ],
                corner_radius: win.corner_radius,
                opacity: win.opacity,
                shadow_expand,
                content_u_max,
                content_v_max,
                _pad: [0.0; 3],
            };
            queue.write_buffer(&self.instance_buffer, 0, bytemuck::bytes_of(&instance));

            let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("composite_window"),
            });

            {
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

            queue.submit([encoder.finish()]);
        }
    }
}
