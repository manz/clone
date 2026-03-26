//! # wgpu-iosurface
//!
//! Zero-copy cross-process GPU texture sharing for wgpu on macOS via IOSurface.
//!
//! IOSurface is a macOS kernel primitive that allows GPU memory to be shared
//! across processes without copies. This crate bridges IOSurface with wgpu
//! by importing IOSurfaces as Metal textures and wrapping them as wgpu textures.
//!
//! ## Usage
//!
//! ```ignore
//! // App process: create a shared texture and render into it
//! let shared = SharedTexture::new(&device, 800, 600, wgpu::TextureFormat::Bgra8Unorm)?;
//! let surface_id = shared.iosurface_id(); // send this to the compositor
//! let view = shared.texture().create_view(&Default::default());
//! // ... render into `view` ...
//!
//! // Compositor process: import the texture by IOSurface ID
//! let imported = SharedTexture::from_id(&device, surface_id, 800, 600, format)?;
//! let view = imported.texture().create_view(&Default::default());
//! // ... composite `view` onto screen ...
//! ```

mod iosurface;
mod texture;

pub use texture::SharedTexture;

// Re-export raw IOSurface functions for testing/advanced use
pub use iosurface::{
    create as iosurface_create, get_id as iosurface_get_id,
    lookup as iosurface_lookup, release as iosurface_release,
    create_mach_port as iosurface_create_mach_port,
    lookup_from_mach_port as iosurface_lookup_from_mach_port,
    mach_port_to_fd as iosurface_mach_port_to_fd,
    fd_to_mach_port as iosurface_fd_to_mach_port,
};
