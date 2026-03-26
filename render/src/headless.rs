use crate::commands::RenderCommand;
use crate::renderer::DesktopRenderer;

/// A headless wgpu rendering context for app-side rendering.
/// Creates a GPU device without a window and renders commands
/// to an offscreen texture, returning BGRA8 pixel data.
pub struct HeadlessDevice {
    device: wgpu::Device,
    queue: wgpu::Queue,
    renderer: DesktopRenderer,
    texture: Option<wgpu::Texture>,
    texture_view: Option<wgpu::TextureView>,
    depth_texture: Option<wgpu::Texture>,
    depth_view: Option<wgpu::TextureView>,
    staging_buffer: Option<wgpu::Buffer>,
    width: u32,
    height: u32,
    format: wgpu::TextureFormat,
}

impl HeadlessDevice {
    /// Create a new headless rendering device.
    /// Uses Bgra8Unorm (linear) format for the offscreen texture.
    pub fn new() -> Result<Self, String> {
        let instance = wgpu::Instance::new(&wgpu::InstanceDescriptor {
            backends: wgpu::Backends::VULKAN | wgpu::Backends::METAL,
            ..Default::default()
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
            texture: None,
            texture_view: None,
            depth_texture: None,
            depth_view: None,
            staging_buffer: None,
            width: 0,
            height: 0,
            format,
        })
    }

    /// Ensure the offscreen texture and staging buffer match the requested size.
    fn ensure_size(&mut self, width: u32, height: u32) {
        let width = width.max(1);
        let height = height.max(1);
        if self.width == width && self.height == height {
            return;
        }
        self.width = width;
        self.height = height;

        let texture = self.device.create_texture(&wgpu::TextureDescriptor {
            label: Some("headless_color"),
            size: wgpu::Extent3d {
                width,
                height,
                depth_or_array_layers: 1,
            },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: self.format,
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT | wgpu::TextureUsages::COPY_SRC,
            view_formats: &[],
        });
        self.texture_view = Some(texture.create_view(&Default::default()));
        self.texture = Some(texture);

        let depth = self.device.create_texture(&wgpu::TextureDescriptor {
            label: Some("headless_depth"),
            size: wgpu::Extent3d {
                width,
                height,
                depth_or_array_layers: 1,
            },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: wgpu::TextureFormat::Depth32Float,
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
            view_formats: &[],
        });
        self.depth_view = Some(depth.create_view(&Default::default()));
        self.depth_texture = Some(depth);

        // Staging buffer for readback — row stride aligned to 256
        let bytes_per_row = Self::aligned_bytes_per_row(width);
        let buffer_size = (bytes_per_row * height) as u64;
        self.staging_buffer = Some(self.device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("headless_staging"),
            size: buffer_size,
            usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
            mapped_at_creation: false,
        }));
    }

    /// Bytes per row aligned to wgpu's 256-byte requirement.
    fn aligned_bytes_per_row(width: u32) -> u32 {
        let unpadded = width * 4;
        (unpadded + 255) & !255
    }

    /// Render commands to an offscreen texture and return BGRA8 pixel data.
    ///
    /// The returned buffer is `width * height * 4` bytes (tightly packed, no padding).
    /// Pixel format is BGRA8 (same as wgpu's Bgra8Unorm).
    /// Set `transparent` to true for overlay surfaces (dock, menubar) that need
    /// a transparent background instead of using the first command's color.
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
        self.ensure_size(phys_w, phys_h);

        let view = self.texture_view.as_ref().unwrap();
        let depth_view = self.depth_view.as_ref().unwrap();

        // Render commands into offscreen texture
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

        // Copy texture to staging buffer
        let bytes_per_row = Self::aligned_bytes_per_row(phys_w);
        encoder.copy_texture_to_buffer(
            wgpu::TexelCopyTextureInfo {
                texture: self.texture.as_ref().unwrap(),
                mip_level: 0,
                origin: wgpu::Origin3d::ZERO,
                aspect: wgpu::TextureAspect::All,
            },
            wgpu::TexelCopyBufferInfo {
                buffer: self.staging_buffer.as_ref().unwrap(),
                layout: wgpu::TexelCopyBufferLayout {
                    offset: 0,
                    bytes_per_row: Some(bytes_per_row),
                    rows_per_image: Some(phys_h),
                },
            },
            wgpu::Extent3d {
                width: phys_w,
                height: phys_h,
                depth_or_array_layers: 1,
            },
        );

        self.queue.submit([encoder.finish()]);

        // Map and read back
        let staging = self.staging_buffer.as_ref().unwrap();
        let slice = staging.slice(..);
        let (tx, rx) = std::sync::mpsc::channel();
        slice.map_async(wgpu::MapMode::Read, move |r| {
            let _ = tx.send(r);
        });
        self.device
            .poll(wgpu::PollType::wait_indefinitely())
            .ok();
        let _ = rx.recv();

        let mapped = slice.get_mapped_range();

        // Strip row padding to produce tightly-packed output
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

        // Convert BGRA to RGBA for PNG
        let mut rgba = Vec::with_capacity(pixels.len());
        for chunk in pixels.chunks_exact(4) {
            rgba.push(chunk[2]); // R (from B)
            rgba.push(chunk[1]); // G
            rgba.push(chunk[0]); // B (from R)
            rgba.push(chunk[3]); // A
        }

        let file =
            std::fs::File::create(path).map_err(|e| format!("Failed to create {path}: {e}"))?;
        let w = std::io::BufWriter::new(file);
        let encoder = image::codecs::png::PngEncoder::new(w);
        use image::ImageEncoder;
        encoder
            .write_image(&rgba, phys_w, phys_h, image::ExtendedColorType::Rgba8)
            .map_err(|e| format!("PNG encode failed: {e}"))?;

        Ok(())
    }

    /// Access the underlying wgpu device.
    pub fn device(&self) -> &wgpu::Device {
        &self.device
    }

    /// Access the underlying wgpu queue.
    pub fn queue(&self) -> &wgpu::Queue {
        &self.queue
    }

    /// Access the renderer for advanced usage.
    pub fn renderer_mut(&mut self) -> &mut DesktopRenderer {
        &mut self.renderer
    }
}
