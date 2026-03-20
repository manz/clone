use std::sync::{Arc, Mutex};

use crate::commands::{RenderCommand, SurfaceFrame};
use crate::renderer::DesktopRenderer;

// ---------------------------------------------------------------------------
// Error type
// ---------------------------------------------------------------------------

#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum EngineError {
    #[error("GPU initialization failed: {reason}")]
    GpuInitFailed { reason: String },
    #[error("Surface error: {reason}")]
    SurfaceError { reason: String },
    #[error("Render error: {reason}")]
    RenderError { reason: String },
}

// ---------------------------------------------------------------------------
// Callback interface — Swift implements this
// ---------------------------------------------------------------------------

#[uniffi::export(callback_interface)]
pub trait DesktopDelegate: Send + Sync {
    /// Old flat API — still used for backwards compat, returns ALL commands.
    fn on_frame(&self, surface_id: u64, width: u32, height: u32) -> Vec<RenderCommand>;
    /// New compositor API — returns per-surface commands for the compositor.
    fn on_composite_frame(&self, width: u32, height: u32) -> Vec<SurfaceFrame>;
    fn on_pointer_move(&self, surface_id: u64, x: f64, y: f64);
    fn on_pointer_button(&self, surface_id: u64, button: u32, pressed: bool);
    fn on_key(&self, surface_id: u64, keycode: u32, pressed: bool);
    /// Returns the file path to the desktop wallpaper image, or empty string for none.
    fn wallpaper_path(&self) -> String;
}

// ---------------------------------------------------------------------------
// Inner state (not exported, behind Mutex)
// ---------------------------------------------------------------------------

struct EngineInner {
    instance: wgpu::Instance,
    device: wgpu::Device,
    queue: wgpu::Queue,
    surface_format: wgpu::TextureFormat,
    renderer: DesktopRenderer,
    delegate: Arc<dyn DesktopDelegate>,
}

// SAFETY: wgpu types are internally thread-safe when accessed through Mutex.
unsafe impl Send for EngineInner {}
unsafe impl Sync for EngineInner {}

// ---------------------------------------------------------------------------
// DesktopEngine — the UniFFI Object
// ---------------------------------------------------------------------------

#[derive(uniffi::Object)]
pub struct DesktopEngine {
    inner: Mutex<EngineInner>,
}

#[uniffi::export]
impl DesktopEngine {
    #[uniffi::constructor]
    pub fn new(delegate: Box<dyn DesktopDelegate>) -> Result<Arc<Self>, EngineError> {
        env_logger::try_init().ok();

        let instance = wgpu::Instance::new(&wgpu::InstanceDescriptor {
            backends: wgpu::Backends::VULKAN | wgpu::Backends::METAL,
            ..Default::default()
        });

        let adapter =
            pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions {
                power_preference: wgpu::PowerPreference::HighPerformance,
                compatible_surface: None,
                force_fallback_adapter: false,
            }))
            .map_err(|e| EngineError::GpuInitFailed {
                reason: e.to_string(),
            })?;

        let (device, queue) =
            pollster::block_on(adapter.request_device(&wgpu::DeviceDescriptor::default()))
                .map_err(|e| EngineError::GpuInitFailed {
                    reason: e.to_string(),
                })?;

        let surface_format = wgpu::TextureFormat::Bgra8UnormSrgb;
        let renderer = DesktopRenderer::new(surface_format);
        let delegate: Arc<dyn DesktopDelegate> = Arc::from(delegate);

        Ok(Arc::new(Self {
            inner: Mutex::new(EngineInner {
                instance,
                device,
                queue,
                surface_format,
                renderer,
                delegate,
            }),
        }))
    }
}

#[uniffi::export]
impl DesktopEngine {
    /// Draw a single frame: ask Swift for commands, render them.
    pub fn draw_frame(
        &self,
        surface_texture_view_hack: u64,
        width: u32,
        height: u32,
    ) -> Result<(), EngineError> {
        let inner = self.inner.lock().unwrap();
        let commands = inner.delegate.on_frame(0, width, height);

        let mut encoder = inner
            .device
            .create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("frame_encoder"),
            });

        // In Phase 1, this is only used by window.rs which provides the real texture view.
        // This method signature will evolve as we add proper surface management.
        let _ = surface_texture_view_hack;
        let _ = &mut encoder;
        let _ = &commands;

        Ok(())
    }

    /// Get the delegate's render commands for a given surface size.
    pub fn get_commands(&self, width: u32, height: u32) -> Vec<RenderCommand> {
        let inner = self.inner.lock().unwrap();
        inner.delegate.on_frame(0, width, height)
    }
}

/// Run the desktop engine with a winit window. This blocks the current thread.
#[uniffi::export]
pub fn run_desktop(delegate: Box<dyn DesktopDelegate>) -> Result<(), EngineError> {
    crate::window::run(delegate)
}
