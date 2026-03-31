use std::sync::Mutex;

use crate::commands::RenderCommand;
use crate::headless::HeadlessDevice;

/// Error type for the render FFI.
#[derive(Debug, thiserror::Error)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Error))]
pub enum RenderError {
    #[error("GPU initialization failed: {reason}")]
    GpuInitFailed { reason: String },
    #[error("Render error: {reason}")]
    RenderFailed { reason: String },
}

/// UniFFI-exported headless renderer for app-side rendering.
/// Thread-safe wrapper around HeadlessDevice.
#[cfg_attr(feature = "uniffi", derive(uniffi::Object))]
pub struct AppRenderer {
    inner: Mutex<HeadlessDevice>,
}

// SAFETY: HeadlessDevice is only accessed through the Mutex.
unsafe impl Send for AppRenderer {}
unsafe impl Sync for AppRenderer {}

#[cfg_attr(feature = "uniffi", uniffi::export)]
impl AppRenderer {
    /// Create a new headless GPU renderer.
    #[cfg_attr(feature = "uniffi", uniffi::constructor)]
    pub fn new() -> Result<Self, RenderError> {
        let device = HeadlessDevice::new().map_err(|e| RenderError::GpuInitFailed {
            reason: e,
        })?;
        Ok(Self {
            inner: Mutex::new(device),
        })
    }

    /// Render commands into a shared texture.
    /// Returns the surface ID for cross-process sharing.
    pub fn render(
        &self,
        commands: Vec<RenderCommand>,
        width: u32,
        height: u32,
        scale: f32,
        transparent: bool,
    ) -> Result<u32, RenderError> {
        let mut device = self.inner.lock().unwrap();
        device
            .render(&commands, width, height, scale, transparent)
            .map_err(|e| RenderError::RenderFailed { reason: e })
    }

    /// Get the current surface ID.
    pub fn iosurface_id(&self) -> u32 {
        self.inner.lock().unwrap().iosurface_id()
    }

    /// Create a Mach port send right for the current front surface (macOS only, returns 0 on Linux).
    pub fn mach_port(&self) -> u32 {
        let device = self.inner.lock().unwrap();
        device.shared_texture().map_or(0, |t| t.mach_port())
    }

    /// Create a Mach port for the surface at the given buffer index (macOS only, returns 0 on Linux).
    pub fn mach_port_at(&self, index: u32) -> u32 {
        let device = self.inner.lock().unwrap();
        device.shared_texture_at(index as usize).map_or(0, |t| t.mach_port())
    }

    /// True if textures were reallocated since the last call.
    pub fn take_textures_changed(&self) -> bool {
        let mut device = self.inner.lock().unwrap();
        let changed = device.textures_changed;
        device.textures_changed = false;
        changed
    }

    /// Render commands to BGRA8 pixel data (readback, slow).
    pub fn render_to_pixels(
        &self,
        commands: Vec<RenderCommand>,
        width: u32,
        height: u32,
        scale: f32,
    ) -> Result<Vec<u8>, RenderError> {
        let mut device = self.inner.lock().unwrap();
        Ok(device.render_to_pixels(&commands, width, height, scale))
    }

    /// Render commands to BGRA8 pixel data with transparent background.
    pub fn render_to_pixels_transparent(
        &self,
        commands: Vec<RenderCommand>,
        width: u32,
        height: u32,
        scale: f32,
    ) -> Result<Vec<u8>, RenderError> {
        let mut device = self.inner.lock().unwrap();
        Ok(device.render_to_pixels_transparent(&commands, width, height, scale))
    }
}

/// Decoded image result.
#[derive(Clone, Debug)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Record))]
pub struct DecodedImage {
    pub width: u32,
    pub height: u32,
    pub rgba_data: Vec<u8>,
}

/// Decode an image file (JPEG, PNG, GIF, BMP, etc.) to RGBA pixel data.
#[cfg_attr(feature = "uniffi", uniffi::export)]
pub fn decode_image(data: Vec<u8>) -> Result<DecodedImage, RenderError> {
    let img = image::load_from_memory(&data)
        .map_err(|e| RenderError::RenderFailed { reason: format!("Image decode failed: {e}") })?;
    let rgba = img.to_rgba8();
    Ok(DecodedImage {
        width: rgba.width(),
        height: rgba.height(),
        rgba_data: rgba.into_raw(),
    })
}
