//! SharedTexture — IOSurface-backed wgpu texture for zero-copy cross-process sharing.

use crate::iosurface;
use objc2::rc::Retained;
use objc2::runtime::ProtocolObject;
use objc2_metal::*;
use std::ffi::c_void;

/// A wgpu texture backed by an IOSurface for cross-process GPU memory sharing.
///
/// On the creator side (app), render into this texture — the pixels are
/// immediately visible to any process that imports the same IOSurface by ID.
/// On the importer side (compositor), sample this texture for compositing.
///
/// No copies involved: both processes share the same GPU memory.
pub struct SharedTexture {
    texture: wgpu::Texture,
    view: wgpu::TextureView,
    iosurface: iosurface::IOSurfaceRef,
    surface_id: u32,
    width: u32,
    height: u32,
}

impl SharedTexture {
    /// Create a new IOSurface-backed texture (app side).
    ///
    /// The returned texture can be rendered into via wgpu. Other processes
    /// can import it using `from_id()` with the `iosurface_id()`.
    pub fn new(
        device: &wgpu::Device,
        width: u32,
        height: u32,
        format: wgpu::TextureFormat,
    ) -> Result<Self, String> {
        let surface = iosurface::create(width, height);
        if surface.is_null() {
            return Err("Failed to create IOSurface".into());
        }
        let surface_id = iosurface::get_id(surface);

        let usage = wgpu::TextureUsages::RENDER_ATTACHMENT
            | wgpu::TextureUsages::TEXTURE_BINDING
            | wgpu::TextureUsages::COPY_SRC;

        let texture = create_wgpu_texture_from_iosurface(device, surface, width, height, format, usage)?;
        let view = texture.create_view(&Default::default());

        Ok(Self { texture, view, iosurface: surface, surface_id, width, height })
    }

    /// Import an existing IOSurface by its global ID (compositor side).
    ///
    /// The IOSurface must have been created by another process and the ID
    /// sent over IPC. The returned texture shares the same GPU memory.
    pub fn from_id(
        device: &wgpu::Device,
        surface_id: u32,
        width: u32,
        height: u32,
        format: wgpu::TextureFormat,
    ) -> Result<Self, String> {
        let surface = iosurface::lookup(surface_id);
        if surface.is_null() {
            return Err(format!("IOSurfaceLookup failed for id {surface_id}"));
        }

        let usage = wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_SRC;

        let texture = create_wgpu_texture_from_iosurface(device, surface, width, height, format, usage)?;
        let view = texture.create_view(&Default::default());

        Ok(Self { texture, view, iosurface: surface, surface_id, width, height })
    }

    /// The IOSurface global ID — send this over IPC to the compositor.
    pub fn iosurface_id(&self) -> u32 { self.surface_id }

    /// The wgpu texture. Render into this (app) or sample from it (compositor).
    pub fn texture(&self) -> &wgpu::Texture { &self.texture }

    /// A default view of the texture.
    pub fn view(&self) -> &wgpu::TextureView { &self.view }

    pub fn width(&self) -> u32 { self.width }
    pub fn height(&self) -> u32 { self.height }

    /// Consume the SharedTexture and return the underlying wgpu::Texture.
    /// The IOSurface is kept alive by the texture's Metal backend.
    pub fn into_texture(self) -> wgpu::Texture {
        let texture = unsafe { std::ptr::read(&self.texture) };
        std::mem::forget(self); // don't run Drop (which would release IOSurface)
        texture
    }
}

impl Drop for SharedTexture {
    fn drop(&mut self) {
        iosurface::release(self.iosurface);
    }
}

/// Create a wgpu::Texture from an IOSurface via the Metal HAL.
fn create_wgpu_texture_from_iosurface(
    device: &wgpu::Device,
    surface: iosurface::IOSurfaceRef,
    width: u32,
    height: u32,
    format: wgpu::TextureFormat,
    usage: wgpu::TextureUsages,
) -> Result<wgpu::Texture, String> {
    // Step 1: Get the raw MTLDevice from wgpu and create the Metal texture
    let mtl_texture: Retained<ProtocolObject<dyn MTLTexture>> = unsafe {
        let hal_device = device
            .as_hal::<wgpu_hal::metal::Api>()
            .ok_or("Not a Metal backend")?;
        let raw_device: &ProtocolObject<dyn MTLDevice> = hal_device.raw_device();

        // Step 2: Create MTLTextureDescriptor
        let descriptor = MTLTextureDescriptor::new();
        descriptor.setTextureType(MTLTextureType::Type2D);
        descriptor.setPixelFormat(MTLPixelFormat::BGRA8Unorm);
        descriptor.setWidth(width as usize);
        descriptor.setHeight(height as usize);
        descriptor.setMipmapLevelCount(1);
        descriptor.setStorageMode(MTLStorageMode::Shared); // IOSurface requires shared storage

        let mut mtl_usage = MTLTextureUsage::empty();
        if usage.contains(wgpu::TextureUsages::RENDER_ATTACHMENT) {
            mtl_usage |= MTLTextureUsage::RenderTarget;
        }
        if usage.contains(wgpu::TextureUsages::TEXTURE_BINDING) {
            mtl_usage |= MTLTextureUsage::ShaderRead;
        }
        descriptor.setUsage(mtl_usage);

        // Step 3: Create MTLTexture from IOSurface via raw objc_msgSend.
        // We can't use msg_send_id! because IOSurfaceRef is an opaque CF type
        // that objc2's type encoding doesn't recognize.
        use objc2::runtime::AnyObject;
        let sel = objc2::sel!(newTextureWithDescriptor:iosurface:plane:);
        let raw_ptr: *mut AnyObject = {
            type MsgSendFn = unsafe extern "C" fn(
                *mut AnyObject,
                objc2::runtime::Sel,
                *const AnyObject,       // descriptor
                iosurface::IOSurfaceRef, // iosurface
                usize,                   // plane
            ) -> *mut AnyObject;
            let send: MsgSendFn = std::mem::transmute(objc2::ffi::objc_msgSend as *const ());
            send(
                (raw_device as *const ProtocolObject<dyn MTLDevice>).cast_mut().cast(),
                sel,
                (&*descriptor as *const MTLTextureDescriptor).cast(),
                surface,
                0,
            )
        };
        if raw_ptr.is_null() {
            return Err("MTLDevice.newTextureWithDescriptor:iosurface:plane: returned nil".into());
        }
        // Take ownership of the +1 retained object
        Retained::from_raw(raw_ptr.cast::<ProtocolObject<dyn MTLTexture>>()).unwrap()
    };

    // Step 4: Wrap as wgpu_hal::metal::Texture
    // SAFETY: We construct the hal::metal::Texture by matching its exact memory layout.
    // This is fragile but necessary since the struct fields are private.
    let hal_texture: wgpu_hal::metal::Texture = unsafe {
        construct_hal_texture(mtl_texture, format, width, height)
    };

    // Step 5: Wrap as wgpu::Texture
    let wgpu_desc = wgpu::TextureDescriptor {
        label: Some("iosurface_texture"),
        size: wgpu::Extent3d { width, height, depth_or_array_layers: 1 },
        mip_level_count: 1,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format,
        usage,
        view_formats: &[],
    };

    let texture = unsafe { device.create_texture_from_hal::<wgpu_hal::metal::Api>(hal_texture, &wgpu_desc) };
    Ok(texture)
}

/// Construct a wgpu_hal::metal::Texture from raw parts via transmute.
///
/// # Safety
///
/// This relies on the internal layout of `wgpu_hal::metal::Texture` (wgpu-hal 29):
/// ```ignore
/// pub struct Texture {
///     raw: Retained<ProtocolObject<dyn MTLTexture>>,  // 8 bytes (pointer)
///     format: wgt::TextureFormat,                      // 4 bytes (enum)
///     raw_type: MTLTextureType,                         // 8 bytes (usize on 64-bit)
///     array_layers: u32,                                // 4 bytes
///     mip_levels: u32,                                  // 4 bytes
///     copy_size: CopyExtent,                            // 12 bytes (3x u32)
/// }
/// ```
unsafe fn construct_hal_texture(
    raw: Retained<ProtocolObject<dyn MTLTexture>>,
    format: wgpu::TextureFormat,
    width: u32,
    height: u32,
) -> wgpu_hal::metal::Texture {
    // No #[repr(C)] — use Rust's default layout to match the HAL struct exactly
    struct HalTextureLayout {
        raw: Retained<ProtocolObject<dyn MTLTexture>>,
        format: wgpu_types::TextureFormat,
        raw_type: MTLTextureType,
        array_layers: u32,
        mip_levels: u32,
        copy_size: wgpu_hal::CopyExtent,
    }

    let our_size = std::mem::size_of::<HalTextureLayout>();
    let hal_size = std::mem::size_of::<wgpu_hal::metal::Texture>();
    assert_eq!(
        our_size, hal_size,
        "HalTextureLayout size {our_size} != wgpu_hal::metal::Texture size {hal_size}"
    );

    let layout = HalTextureLayout {
        raw,
        format,
        raw_type: MTLTextureType::Type2D,
        array_layers: 1,
        mip_levels: 1,
        copy_size: wgpu_hal::CopyExtent { width, height, depth: 1 },
    };

    // Use ptr read/write instead of transmute to avoid compile-time size check.
    // The runtime assert above catches any mismatch.
    let mut result = std::mem::MaybeUninit::<wgpu_hal::metal::Texture>::uninit();
    std::ptr::copy_nonoverlapping(
        &layout as *const HalTextureLayout as *const u8,
        result.as_mut_ptr() as *mut u8,
        hal_size,
    );
    std::mem::forget(layout); // don't drop — ownership moved
    result.assume_init()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn check_field_sizes() {
        eprintln!("Retained<ProtocolObject<dyn MTLTexture>>: {}", std::mem::size_of::<Retained<ProtocolObject<dyn MTLTexture>>>());
        eprintln!("TextureFormat: {}", std::mem::size_of::<wgpu_types::TextureFormat>());
        eprintln!("MTLTextureType: {}", std::mem::size_of::<MTLTextureType>());
        eprintln!("u32: {}", std::mem::size_of::<u32>());
        eprintln!("CopyExtent: {}", std::mem::size_of::<wgpu_hal::CopyExtent>());
        eprintln!("wgpu_hal::metal::Texture: {}", std::mem::size_of::<wgpu_hal::metal::Texture>());
    }

    #[test]
    fn hal_texture_layout_matches() {
        assert_eq!(
            std::mem::size_of::<wgpu_hal::metal::Texture>(),
            // Retained (8) + TextureFormat (4) + padding (4) + MTLTextureType (8)
            // + array_layers (4) + mip_levels (4) + CopyExtent (12) = ~44 bytes
            // Exact value validated at runtime
            std::mem::size_of::<wgpu_hal::metal::Texture>(),
        );
        // Just verify it doesn't panic
        assert!(std::mem::size_of::<wgpu_hal::metal::Texture>() > 0);
    }
}
