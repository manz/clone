//! Linux backend — DMA-BUF backed wgpu texture for zero-copy cross-process sharing.
//!
//! Uses Vulkan external memory (VK_EXT_external_memory_dma_buf) to export/import
//! GPU textures as DMA-BUF file descriptors. Same architecture as macOS IOSurface:
//! app renders into SharedTexture, exports fd via SCM_RIGHTS, compositor imports it.

use ash::vk;
use std::os::fd::{FromRawFd, IntoRawFd, OwnedFd};
use std::sync::atomic::{AtomicU32, Ordering};

static NEXT_ID: AtomicU32 = AtomicU32::new(1);

/// A wgpu texture backed by DMA-BUF for cross-process GPU memory sharing.
pub struct SharedTexture {
    texture: wgpu::Texture,
    view: wgpu::TextureView,
    surface_id: u32,
    width: u32,
    height: u32,
    /// DMA-BUF fd for cross-process sharing. None if imported (fd owned by creator).
    dmabuf_fd: Option<OwnedFd>,
    /// Vulkan image/memory handles for cleanup.
    vk_image: vk::Image,
    vk_memory: vk::DeviceMemory,
}

impl SharedTexture {
    /// Create a new DMA-BUF-backed texture (app side).
    pub fn new(
        device: &wgpu::Device,
        width: u32,
        height: u32,
        format: wgpu::TextureFormat,
    ) -> Result<Self, String> {
        let surface_id = NEXT_ID.fetch_add(1, Ordering::Relaxed);
        let usage = wgpu::TextureUsages::RENDER_ATTACHMENT
            | wgpu::TextureUsages::TEXTURE_BINDING
            | wgpu::TextureUsages::COPY_SRC;

        let (texture, vk_image, vk_memory, fd) =
            create_exportable_texture(device, width, height, format, usage)?;
        let view = texture.create_view(&Default::default());

        Ok(Self {
            texture, view, surface_id, width, height,
            dmabuf_fd: Some(fd), vk_image, vk_memory,
        })
    }

    /// Import a DMA-BUF texture from a file descriptor (compositor side).
    pub fn from_fd(
        device: &wgpu::Device,
        fd: i32,
        width: u32,
        height: u32,
        format: wgpu::TextureFormat,
    ) -> Result<Self, String> {
        let surface_id = NEXT_ID.fetch_add(1, Ordering::Relaxed);
        let usage = wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_SRC;

        let (texture, vk_image, vk_memory) =
            import_dmabuf_texture(device, fd, width, height, format, usage)?;
        let view = texture.create_view(&Default::default());

        Ok(Self {
            texture, view, surface_id, width, height,
            dmabuf_fd: None, vk_image, vk_memory,
        })
    }

    /// Export the DMA-BUF as a file descriptor for cross-process transfer via SCM_RIGHTS.
    /// Returns a dup'd fd — caller must close it after sendmsg.
    pub fn export_fd(&self) -> Result<i32, String> {
        match &self.dmabuf_fd {
            Some(fd) => {
                let raw = unsafe { libc::dup(std::os::fd::AsRawFd::as_raw_fd(fd)) };
                if raw < 0 {
                    Err("dup() failed on DMA-BUF fd".into())
                } else {
                    Ok(raw)
                }
            }
            None => Err("No DMA-BUF fd (imported texture)".into()),
        }
    }

    /// Import from ID — not used on Linux (use from_fd instead).
    pub fn from_id(
        _device: &wgpu::Device,
        _surface_id: u32,
        _width: u32,
        _height: u32,
        _format: wgpu::TextureFormat,
    ) -> Result<Self, String> {
        Err("SharedTexture::from_id not available on Linux — use from_fd".into())
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

    pub fn into_texture(self) -> wgpu::Texture {
        let texture = unsafe { std::ptr::read(&self.texture) };
        std::mem::forget(self);
        texture
    }
}

// -- Vulkan DMA-BUF creation / import --

/// Create a Vulkan image with exportable DMA-BUF memory, wrap as wgpu texture.
fn create_exportable_texture(
    device: &wgpu::Device,
    width: u32,
    height: u32,
    format: wgpu::TextureFormat,
    usage: wgpu::TextureUsages,
) -> Result<(wgpu::Texture, vk::Image, vk::DeviceMemory, OwnedFd), String> {
    unsafe {
        let hal_device = device
            .as_hal::<wgpu_hal::vulkan::Api>()
            .ok_or("Not a Vulkan backend")?;
        let raw_device = hal_device.raw_device();
        let vk_format = to_vk_format(format);

        // External memory info — we want DMA-BUF export
        let mut ext_info = vk::ExternalMemoryImageCreateInfo::default()
            .handle_types(vk::ExternalMemoryHandleTypeFlags::DMA_BUF_EXT);

        let image_info = vk::ImageCreateInfo::default()
            .image_type(vk::ImageType::TYPE_2D)
            .format(vk_format)
            .extent(vk::Extent3D { width, height, depth: 1 })
            .mip_levels(1)
            .array_layers(1)
            .samples(vk::SampleCountFlags::TYPE_1)
            .tiling(vk::ImageTiling::LINEAR)
            .usage(to_vk_image_usage(usage))
            .sharing_mode(vk::SharingMode::EXCLUSIVE)
            .initial_layout(vk::ImageLayout::UNDEFINED)
            .push_next(&mut ext_info);

        let vk_image = raw_device.create_image(&image_info, None)
            .map_err(|e| format!("vkCreateImage: {e}"))?;

        let mem_reqs = raw_device.get_image_memory_requirements(vk_image);

        // Allocate with export capability
        let mut export_info = vk::ExportMemoryAllocateInfo::default()
            .handle_types(vk::ExternalMemoryHandleTypeFlags::DMA_BUF_EXT);

        let mem_type_index = find_memory_type(&hal_device, mem_reqs.memory_type_bits,
            vk::MemoryPropertyFlags::DEVICE_LOCAL | vk::MemoryPropertyFlags::HOST_VISIBLE)
            .or_else(|| find_memory_type(&hal_device, mem_reqs.memory_type_bits,
                vk::MemoryPropertyFlags::DEVICE_LOCAL))
            .ok_or("No suitable memory type for DMA-BUF export")?;

        let alloc_info = vk::MemoryAllocateInfo::default()
            .allocation_size(mem_reqs.size)
            .memory_type_index(mem_type_index)
            .push_next(&mut export_info);

        let vk_memory = raw_device.allocate_memory(&alloc_info, None)
            .map_err(|e| format!("vkAllocateMemory: {e}"))?;

        raw_device.bind_image_memory(vk_image, vk_memory, 0)
            .map_err(|e| format!("vkBindImageMemory: {e}"))?;

        // Export as DMA-BUF fd
        let fd_info = vk::MemoryGetFdInfoKHR::default()
            .memory(vk_memory)
            .handle_type(vk::ExternalMemoryHandleTypeFlags::DMA_BUF_EXT);

        let ext_mem_fd = ash::khr::external_memory_fd::Device::new(
            hal_device.shared_instance().raw_instance(), raw_device);
        let raw_fd = ext_mem_fd.get_memory_fd(&fd_info)
            .map_err(|e| format!("vkGetMemoryFdKHR: {e}"))?;

        let owned_fd = OwnedFd::from_raw_fd(raw_fd);

        // Wrap as wgpu texture via the public HAL API
        let hal_desc = wgpu_hal::TextureDescriptor {
            label: Some("dmabuf_texture"),
            size: wgpu::Extent3d { width, height, depth_or_array_layers: 1 },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format,
            usage: to_hal_usage(usage),
            memory_flags: wgpu_hal::MemoryFlags::empty(),
            view_formats: vec![],
        };
        let hal_texture = hal_device.texture_from_raw(
            vk_image, &hal_desc, None,
            wgpu_hal::vulkan::TextureMemory::External,
        );
        let wgpu_desc = wgpu::TextureDescriptor {
            label: Some("dmabuf_texture"),
            size: wgpu::Extent3d { width, height, depth_or_array_layers: 1 },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format,
            usage,
            view_formats: &[],
        };
        let texture = device.create_texture_from_hal::<wgpu_hal::vulkan::Api>(hal_texture, &wgpu_desc);

        Ok((texture, vk_image, vk_memory, owned_fd))
    }
}

/// Import a DMA-BUF fd as a Vulkan image, wrap as wgpu texture.
fn import_dmabuf_texture(
    device: &wgpu::Device,
    fd: i32,
    width: u32,
    height: u32,
    format: wgpu::TextureFormat,
    usage: wgpu::TextureUsages,
) -> Result<(wgpu::Texture, vk::Image, vk::DeviceMemory), String> {
    unsafe {
        let hal_device = device
            .as_hal::<wgpu_hal::vulkan::Api>()
            .ok_or("Not a Vulkan backend")?;
        let raw_device = hal_device.raw_device();
        let vk_format = to_vk_format(format);

        // Create image compatible with DMA-BUF import
        let mut ext_info = vk::ExternalMemoryImageCreateInfo::default()
            .handle_types(vk::ExternalMemoryHandleTypeFlags::DMA_BUF_EXT);

        let image_info = vk::ImageCreateInfo::default()
            .image_type(vk::ImageType::TYPE_2D)
            .format(vk_format)
            .extent(vk::Extent3D { width, height, depth: 1 })
            .mip_levels(1)
            .array_layers(1)
            .samples(vk::SampleCountFlags::TYPE_1)
            .tiling(vk::ImageTiling::LINEAR)
            .usage(to_vk_image_usage(usage))
            .sharing_mode(vk::SharingMode::EXCLUSIVE)
            .initial_layout(vk::ImageLayout::UNDEFINED)
            .push_next(&mut ext_info);

        let vk_image = raw_device.create_image(&image_info, None)
            .map_err(|e| format!("vkCreateImage (import): {e}"))?;

        let mem_reqs = raw_device.get_image_memory_requirements(vk_image);

        // Import the DMA-BUF fd as Vulkan memory
        // dup the fd because Vulkan takes ownership
        let import_fd = libc::dup(fd);
        if import_fd < 0 {
            raw_device.destroy_image(vk_image, None);
            return Err("dup() failed on import fd".into());
        }

        let mut import_info = vk::ImportMemoryFdInfoKHR::default()
            .handle_type(vk::ExternalMemoryHandleTypeFlags::DMA_BUF_EXT)
            .fd(import_fd);

        let mem_type_index = find_memory_type(&hal_device, mem_reqs.memory_type_bits,
            vk::MemoryPropertyFlags::DEVICE_LOCAL)
            .ok_or("No suitable memory type for DMA-BUF import")?;

        let alloc_info = vk::MemoryAllocateInfo::default()
            .allocation_size(mem_reqs.size)
            .memory_type_index(mem_type_index)
            .push_next(&mut import_info);

        let vk_memory = raw_device.allocate_memory(&alloc_info, None)
            .map_err(|e| {
                libc::close(import_fd);
                raw_device.destroy_image(vk_image, None);
                format!("vkAllocateMemory (import): {e}")
            })?;

        raw_device.bind_image_memory(vk_image, vk_memory, 0)
            .map_err(|e| format!("vkBindImageMemory (import): {e}"))?;

        let hal_desc = wgpu_hal::TextureDescriptor {
            label: Some("dmabuf_import"),
            size: wgpu::Extent3d { width, height, depth_or_array_layers: 1 },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format,
            usage: to_hal_usage(usage),
            memory_flags: wgpu_hal::MemoryFlags::empty(),
            view_formats: vec![],
        };
        let hal_texture = hal_device.texture_from_raw(
            vk_image, &hal_desc, None,
            wgpu_hal::vulkan::TextureMemory::External,
        );
        let wgpu_desc = wgpu::TextureDescriptor {
            label: Some("dmabuf_import"),
            size: wgpu::Extent3d { width, height, depth_or_array_layers: 1 },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format,
            usage,
            view_formats: &[],
        };
        let texture = device.create_texture_from_hal::<wgpu_hal::vulkan::Api>(hal_texture, &wgpu_desc);

        Ok((texture, vk_image, vk_memory))
    }
}

// -- Helpers --

fn to_hal_usage(usage: wgpu::TextureUsages) -> wgpu_types::TextureUses {
    let mut flags = wgpu_types::TextureUses::empty();
    if usage.contains(wgpu::TextureUsages::RENDER_ATTACHMENT) {
        flags |= wgpu_types::TextureUses::COLOR_TARGET;
    }
    if usage.contains(wgpu::TextureUsages::TEXTURE_BINDING) {
        flags |= wgpu_types::TextureUses::RESOURCE;
    }
    if usage.contains(wgpu::TextureUsages::COPY_SRC) {
        flags |= wgpu_types::TextureUses::COPY_SRC;
    }
    if usage.contains(wgpu::TextureUsages::COPY_DST) {
        flags |= wgpu_types::TextureUses::COPY_DST;
    }
    flags
}

fn to_vk_format(format: wgpu::TextureFormat) -> vk::Format {
    match format {
        wgpu::TextureFormat::Bgra8Unorm => vk::Format::B8G8R8A8_UNORM,
        wgpu::TextureFormat::Rgba8Unorm => vk::Format::R8G8B8A8_UNORM,
        wgpu::TextureFormat::Bgra8UnormSrgb => vk::Format::B8G8R8A8_SRGB,
        wgpu::TextureFormat::Rgba8UnormSrgb => vk::Format::R8G8B8A8_SRGB,
        _ => vk::Format::B8G8R8A8_UNORM, // fallback
    }
}

fn to_vk_image_usage(usage: wgpu::TextureUsages) -> vk::ImageUsageFlags {
    let mut flags = vk::ImageUsageFlags::empty();
    if usage.contains(wgpu::TextureUsages::RENDER_ATTACHMENT) {
        flags |= vk::ImageUsageFlags::COLOR_ATTACHMENT;
    }
    if usage.contains(wgpu::TextureUsages::TEXTURE_BINDING) {
        flags |= vk::ImageUsageFlags::SAMPLED;
    }
    if usage.contains(wgpu::TextureUsages::COPY_SRC) {
        flags |= vk::ImageUsageFlags::TRANSFER_SRC;
    }
    if usage.contains(wgpu::TextureUsages::COPY_DST) {
        flags |= vk::ImageUsageFlags::TRANSFER_DST;
    }
    flags
}

fn find_memory_type(
    hal_device: &wgpu_hal::vulkan::Device,
    type_bits: u32,
    required: vk::MemoryPropertyFlags,
) -> Option<u32> {
    let instance = hal_device.shared_instance().raw_instance();
    let phys_device = hal_device.raw_physical_device();
    let props = unsafe { instance.get_physical_device_memory_properties(phys_device) };
    for i in 0..props.memory_type_count {
        if type_bits & (1 << i) != 0 {
            if props.memory_types[i as usize].property_flags.contains(required) {
                return Some(i);
            }
        }
    }
    None
}
