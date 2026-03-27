use crate::commands::RenderCommand;
use crate::renderer::DesktopRenderer;
use wgpu_iosurface::SharedTexture;

/// A headless wgpu rendering context for app-side rendering.
/// Double-buffered IOSurface textures: app renders to back, compositor reads front.
/// Zero-copy cross-process sharing via Mach ports.
pub struct HeadlessDevice {
    device: wgpu::Device,
    queue: wgpu::Queue,
    renderer: DesktopRenderer,
    /// Double-buffered: [0] and [1] alternate as front/back.
    textures: [Option<SharedTexture>; 2],
    depth_texture: Option<wgpu::Texture>,
    depth_view: Option<wgpu::TextureView>,
    /// Which texture index is currently the "front" (compositor-visible).
    front: usize,
    width: u32,
    height: u32,
    format: wgpu::TextureFormat,
    /// True when textures were just reallocated (new Mach ports needed).
    pub textures_changed: bool,
}

impl HeadlessDevice {
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
            textures: [None, None],
            depth_texture: None,
            depth_view: None,
            front: 0,
            width: 0,
            height: 0,
            format,
            textures_changed: false,
        })
    }

    /// Ensure textures match the requested physical size exactly.
    /// Reallocates only when size changes. Sets `textures_changed` flag
    /// so the caller knows new Mach ports need to be sent.
    fn ensure_size(&mut self, width: u32, height: u32) -> Result<(), String> {
        let width = width.max(1);
        let height = height.max(1);

        if self.textures[0].is_none() || self.width != width || self.height != height {
            self.width = width;
            self.height = height;

            self.textures[0] = Some(SharedTexture::new(&self.device, width, height, self.format)?);
            self.textures[1] = Some(SharedTexture::new(&self.device, width, height, self.format)?);
            self.front = 0;
            self.textures_changed = true;

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

        Ok(())
    }

    fn back_index(&self) -> usize { 1 - self.front }

    /// Get the current front (compositor-visible) IOSurface ID.
    pub fn iosurface_id(&self) -> u32 {
        self.textures[self.front].as_ref().map_or(0, |t| t.iosurface_id())
    }

    /// Get IOSurface IDs for both buffers (for Mach port registration).
    pub fn both_iosurface_ids(&self) -> [u32; 2] {
        [
            self.textures[0].as_ref().map_or(0, |t| t.iosurface_id()),
            self.textures[1].as_ref().map_or(0, |t| t.iosurface_id()),
        ]
    }

    /// Get the current front texture.
    pub fn shared_texture(&self) -> Option<&SharedTexture> {
        self.textures[self.front].as_ref()
    }

    /// Get a texture by index (for Mach port export of both buffers).
    pub fn shared_texture_at(&self, index: usize) -> Option<&SharedTexture> {
        self.textures.get(index).and_then(|t| t.as_ref())
    }

    /// Render commands into the back texture, then swap front/back.
    /// Returns the new front IOSurface ID.
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
        self.ensure_size(phys_w, phys_h)?;

        let back = self.back_index();
        let view = self.textures[back].as_ref().unwrap().view();
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
        self.device.poll(wgpu::PollType::wait_indefinitely()).ok();

        // Swap: back becomes the new front
        self.front = back;

        Ok(self.textures[self.front].as_ref().unwrap().iosurface_id())
    }

    /// Render commands to BGRA8 pixel data (testing/PNG export only).
    pub fn render_to_pixels(
        &mut self,
        commands: &[RenderCommand],
        width: u32,
        height: u32,
        scale: f32,
    ) -> Vec<u8> {
        self.render_to_pixels_inner(commands, width, height, scale, false)
    }

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

        let back = self.back_index();
        let texture = self.textures[back].as_ref().unwrap().texture();
        let view = self.textures[back].as_ref().unwrap().view();
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
}
