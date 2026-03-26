use crate::commands::RenderCommand;
use crate::renderer::DesktopRenderer;
use wgpu_iosurface::SharedTexture;

/// A headless wgpu rendering context for app-side rendering.
/// Renders into an IOSurface-backed texture for zero-copy cross-process sharing.
/// The compositor imports the same IOSurface by ID — no copies involved.
pub struct HeadlessDevice {
    device: wgpu::Device,
    queue: wgpu::Queue,
    renderer: DesktopRenderer,
    shared_texture: Option<SharedTexture>,
    depth_texture: Option<wgpu::Texture>,
    depth_view: Option<wgpu::TextureView>,
    width: u32,
    height: u32,
    format: wgpu::TextureFormat,
}

impl HeadlessDevice {
    /// Create a new headless rendering device.
    /// Uses Bgra8Unorm (linear) format for the offscreen texture.
    pub fn new() -> Result<Self, String> {
        let instance = wgpu::Instance::new(wgpu::InstanceDescriptor {
            backends: wgpu::Backends::VULKAN | wgpu::Backends::METAL,
            backend_options: wgpu::BackendOptions::default(),
            flags: wgpu::InstanceFlags::default(),
            memory_budget_thresholds: wgpu::MemoryBudgetThresholds::default(),
            display: None,
        });

        let adapter = pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions {
            power_preference: wgpu::PowerPreference::HighPerformance,
            compatible_surface: None,
            force_fallback_adapter: false,
        }))
        .map_err(|e| format!("Failed to get GPU adapter: {e}"))?;

        let (device, queue) =
            pollster::block_on(adapter.request_device(&wgpu::DeviceDescriptor::default()))
                .map_err(|e| format!("Failed to get GPU device: {e}"))?;

        let format = wgpu::TextureFormat::Bgra8Unorm;
        let mut renderer = DesktopRenderer::new(format);
        renderer.init_pipelines(&device, &queue);

        Ok(Self {
            device,
            queue,
            renderer,
            shared_texture: None,
            depth_texture: None,
            depth_view: None,
            width: 0,
            height: 0,
            format,
        })
    }

    /// Ensure the shared texture matches the requested physical size.
    /// Returns the IOSurface ID (changes on resize).
    fn ensure_size(&mut self, width: u32, height: u32) -> Result<u32, String> {
        let width = width.max(1);
        let height = height.max(1);

        if self.width != width || self.height != height {
            self.width = width;
            self.height = height;

            // Create new IOSurface-backed shared texture
            self.shared_texture = Some(SharedTexture::new(&self.device, width, height, self.format)?);

            // Create depth texture
            let depth = self.device.create_texture(&wgpu::TextureDescriptor {
                label: Some("headless_depth"),
                size: wgpu::Extent3d { width, height, depth_or_array_layers: 1 },
                mip_level_count: 1,
                sample_count: 1,
                dimension: wgpu::TextureDimension::D2,
                format: wgpu::TextureFormat::Depth32Float,
                usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
                view_formats: &[],
            });
            self.depth_view = Some(depth.create_view(&Default::default()));
            self.depth_texture = Some(depth);
        }

        Ok(self.shared_texture.as_ref().unwrap().iosurface_id())
    }

    /// Get the current IOSurface ID. Returns 0 if no texture has been created yet.
    pub fn iosurface_id(&self) -> u32 {
        self.shared_texture.as_ref().map_or(0, |t| t.iosurface_id())
    }

    /// Render commands into the IOSurface-backed texture.
    /// Returns the IOSurface ID for cross-process sharing.
    /// No readback, no copies — the compositor imports by this ID.
    pub fn render(
        &mut self,
        commands: &[RenderCommand],
        width: u32,
        height: u32,
        scale: f32,
        transparent: bool,
    ) -> Result<u32, String> {
        let phys_w = ((width as f32) * scale) as u32;
        let phys_h = ((height as f32) * scale) as u32;
        let iosurface_id = self.ensure_size(phys_w, phys_h)?;

        let view = self.shared_texture.as_ref().unwrap().view();
        let depth_view = self.depth_view.as_ref().unwrap();

        let mut encoder = self
            .device
            .create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("headless_render"),
            });

        if transparent {
            self.renderer.render_transparent(
                &self.device, &self.queue, &mut encoder,
                view, depth_view, commands, phys_w, phys_h, scale,
            );
        } else {
            self.renderer.render(
                &self.device, &self.queue, &mut encoder,
                view, depth_view, commands, phys_w, phys_h, scale,
            );
        }

        self.queue.submit([encoder.finish()]);

        Ok(iosurface_id)
    }

    /// Render commands to BGRA8 pixel data (legacy path for testing/PNG export).
    pub fn render_to_pixels(
        &mut self,
        commands: &[RenderCommand],
        width: u32,
        height: u32,
        scale: f32,
    ) -> Vec<u8> {
        self.render_to_pixels_inner(commands, width, height, scale, false)
    }

    /// Same as `render_to_pixels` but with a transparent clear color.
    pub fn render_to_pixels_transparent(
        &mut self,
        commands: &[RenderCommand],
        width: u32,
        height: u32,
        scale: f32,
    ) -> Vec<u8> {
        self.render_to_pixels_inner(commands, width, height, scale, true)
    }

    fn render_to_pixels_inner(
        &mut self,
        commands: &[RenderCommand],
        width: u32,
        height: u32,
        scale: f32,
        transparent: bool,
    ) -> Vec<u8> {
        let phys_w = ((width as f32) * scale) as u32;
        let phys_h = ((height as f32) * scale) as u32;
        let _ = self.ensure_size(phys_w, phys_h);

        let texture = self.shared_texture.as_ref().unwrap().texture();
        let view = self.shared_texture.as_ref().unwrap().view();
        let depth_view = self.depth_view.as_ref().unwrap();

        let mut encoder = self.device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
            label: Some("headless_render"),
        });

        if transparent {
            self.renderer.render_transparent(
                &self.device, &self.queue, &mut encoder,
                view, depth_view, commands, phys_w, phys_h, scale,
            );
        } else {
            self.renderer.render(
                &self.device, &self.queue, &mut encoder,
                view, depth_view, commands, phys_w, phys_h, scale,
            );
        }

        // Readback from the IOSurface texture
        let bytes_per_row = Self::aligned_bytes_per_row(phys_w);
        let buffer_size = (bytes_per_row * phys_h) as u64;
        let staging = self.device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("readback"),
            size: buffer_size,
            usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
            mapped_at_creation: false,
        });

        encoder.copy_texture_to_buffer(
            wgpu::TexelCopyTextureInfo {
                texture,
                mip_level: 0,
                origin: wgpu::Origin3d::ZERO,
                aspect: wgpu::TextureAspect::All,
            },
            wgpu::TexelCopyBufferInfo {
                buffer: &staging,
                layout: wgpu::TexelCopyBufferLayout {
                    offset: 0,
                    bytes_per_row: Some(bytes_per_row),
                    rows_per_image: Some(phys_h),
                },
            },
            wgpu::Extent3d { width: phys_w, height: phys_h, depth_or_array_layers: 1 },
        );
        self.queue.submit([encoder.finish()]);

        let slice = staging.slice(..);
        let (tx, rx) = std::sync::mpsc::channel();
        slice.map_async(wgpu::MapMode::Read, move |r| { let _ = tx.send(r); });
        self.device.poll(wgpu::PollType::wait_indefinitely()).ok();
        let _ = rx.recv();

        let mapped = slice.get_mapped_range();
        let tight_row = (phys_w * 4) as usize;
        let mut pixels = Vec::with_capacity(tight_row * phys_h as usize);
        for row in 0..phys_h {
            let start = (row * bytes_per_row) as usize;
            pixels.extend_from_slice(&mapped[start..start + tight_row]);
        }
        drop(mapped);
        staging.unmap();
        pixels
    }

    fn aligned_bytes_per_row(width: u32) -> u32 {
        (width * 4 + 255) & !255
    }

    /// Render commands and save as a PNG file (for testing).
    pub fn render_to_png(
        &mut self,
        commands: &[RenderCommand],
        width: u32,
        height: u32,
        scale: f32,
        path: &str,
    ) -> Result<(), String> {
        let pixels = self.render_to_pixels(commands, width, height, scale);
        let phys_w = ((width as f32) * scale) as u32;
        let phys_h = ((height as f32) * scale) as u32;

        let mut rgba = Vec::with_capacity(pixels.len());
        for chunk in pixels.chunks_exact(4) {
            rgba.push(chunk[2]);
            rgba.push(chunk[1]);
            rgba.push(chunk[0]);
            rgba.push(chunk[3]);
        }

        let file = std::fs::File::create(path).map_err(|e| format!("Failed to create {path}: {e}"))?;
        let w = std::io::BufWriter::new(file);
        let encoder = image::codecs::png::PngEncoder::new(w);
        use image::ImageEncoder;
        encoder.write_image(&rgba, phys_w, phys_h, image::ExtendedColorType::Rgba8)
            .map_err(|e| format!("PNG encode failed: {e}"))?;
        Ok(())
    }

    pub fn device(&self) -> &wgpu::Device { &self.device }
    pub fn queue(&self) -> &wgpu::Queue { &self.queue }
    pub fn renderer_mut(&mut self) -> &mut DesktopRenderer { &mut self.renderer }
    pub fn shared_texture(&self) -> Option<&SharedTexture> { self.shared_texture.as_ref() }
}
