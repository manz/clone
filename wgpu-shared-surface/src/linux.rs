//! Linux backend — regular wgpu texture, no cross-process sharing yet.
//!
//! Future: DMA-BUF via Vulkan external memory for zero-copy.

use std::sync::atomic::{AtomicU32, Ordering};

static NEXT_ID: AtomicU32 = AtomicU32::new(1);

/// A GPU texture on Linux. Same API as the macOS SharedTexture but without
/// cross-process sharing — apps use pixel readback for IPC.
pub struct SharedTexture {
    texture: wgpu::Texture,
    view: wgpu::TextureView,
    surface_id: u32,
    width: u32,
    height: u32,
}

impl SharedTexture {
    pub fn new(
        device: &wgpu::Device,
        width: u32,
        height: u32,
        format: wgpu::TextureFormat,
    ) -> Result<Self, String> {
        let surface_id = NEXT_ID.fetch_add(1, Ordering::Relaxed);
        let texture = device.create_texture(&wgpu::TextureDescriptor {
            label: Some("shared_surface"),
            size: wgpu::Extent3d { width, height, depth_or_array_layers: 1 },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format,
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT
                | wgpu::TextureUsages::TEXTURE_BINDING
                | wgpu::TextureUsages::COPY_SRC,
            view_formats: &[],
        });
        let view = texture.create_view(&Default::default());
        Ok(Self { texture, view, surface_id, width, height })
    }

    pub fn from_id(
        _device: &wgpu::Device,
        _surface_id: u32,
        _width: u32,
        _height: u32,
        _format: wgpu::TextureFormat,
    ) -> Result<Self, String> {
        Err("SharedTexture::from_id not available on Linux".into())
    }

    pub fn iosurface_id(&self) -> u32 { self.surface_id }
    pub fn surface_id(&self) -> u32 { self.surface_id }
    pub fn mach_port(&self) -> u32 { 0 }

    pub fn from_mach_port(
        _device: &wgpu::Device,
        _port: u32,
        _width: u32,
        _height: u32,
        _format: wgpu::TextureFormat,
    ) -> Result<Self, String> {
        Err("Mach ports not available on Linux".into())
    }

    pub fn texture(&self) -> &wgpu::Texture { &self.texture }
    pub fn view(&self) -> &wgpu::TextureView { &self.view }
    pub fn width(&self) -> u32 { self.width }
    pub fn height(&self) -> u32 { self.height }

    pub fn into_texture(self) -> wgpu::Texture { self.texture }
}
