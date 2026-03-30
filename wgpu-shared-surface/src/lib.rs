//! # wgpu-shared-surface
//!
//! Cross-platform GPU surface sharing for wgpu.
//!
//! - **macOS**: IOSurface + Mach ports — zero-copy cross-process GPU memory sharing
//! - **Linux**: regular wgpu texture + pixel readback (DMA-BUF zero-copy future)
//!
//! Both platforms export the same [`SharedTexture`] type.

#[cfg(target_os = "macos")]
mod iosurface;
#[cfg(target_os = "macos")]
mod texture;
#[cfg(target_os = "linux")]
mod linux;

#[cfg(target_os = "macos")]
pub use texture::SharedTexture;
#[cfg(target_os = "linux")]
pub use linux::SharedTexture;

// Re-export raw IOSurface functions for compositor-level use (macOS only)
#[cfg(target_os = "macos")]
pub use iosurface::{
    create as iosurface_create, get_id as iosurface_get_id,
    lookup as iosurface_lookup, release as iosurface_release,
    create_mach_port as iosurface_create_mach_port,
    lookup_from_mach_port as iosurface_lookup_from_mach_port,
    mach_port_to_fd as iosurface_mach_port_to_fd,
    fd_to_mach_port as iosurface_fd_to_mach_port,
    IOSurfaceGetWidth as iosurface_get_width,
    IOSurfaceGetHeight as iosurface_get_height,
};
