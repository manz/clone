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

    /// Render commands to BGRA8 pixel data.
    /// Returns tightly-packed pixels (width * height * 4 bytes at the given scale).
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
}
