use std::sync::Arc;

use winit::application::ApplicationHandler;
use winit::dpi::LogicalSize;
use winit::event::WindowEvent;
use winit::event_loop::{ActiveEventLoop, EventLoop};
use winit::window::{Window, WindowId};

use crate::ffi::{DesktopDelegate, EngineError};
use crate::renderer::DesktopRenderer;

struct GpuState {
    device: wgpu::Device,
    queue: wgpu::Queue,
    surface: wgpu::Surface<'static>,
    surface_config: wgpu::SurfaceConfiguration,
    renderer: DesktopRenderer,
}

struct App {
    delegate: Arc<dyn DesktopDelegate>,
    window: Option<Arc<Window>>,
    gpu: Option<GpuState>,
}

impl App {
    fn new(delegate: Box<dyn DesktopDelegate>) -> Self {
        Self {
            delegate: Arc::from(delegate),
            window: None,
            gpu: None,
        }
    }

    fn init_gpu(&mut self, window: Arc<Window>) -> Result<(), EngineError> {
        let instance = wgpu::Instance::new(&wgpu::InstanceDescriptor {
            backends: wgpu::Backends::VULKAN | wgpu::Backends::METAL,
            ..Default::default()
        });

        let surface = instance
            .create_surface(window.clone())
            .map_err(|e| EngineError::SurfaceError {
                reason: e.to_string(),
            })?;

        let adapter =
            pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions {
                power_preference: wgpu::PowerPreference::HighPerformance,
                compatible_surface: Some(&surface),
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

        let caps = surface.get_capabilities(&adapter);
        let surface_format = caps.formats[0];

        let size = window.inner_size();
        let surface_config = wgpu::SurfaceConfiguration {
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
            format: surface_format,
            view_formats: vec![],
            alpha_mode: wgpu::CompositeAlphaMode::Auto,
            width: size.width.max(1),
            height: size.height.max(1),
            desired_maximum_frame_latency: 2,
            present_mode: wgpu::PresentMode::AutoVsync,
        };
        surface.configure(&device, &surface_config);

        let mut renderer = DesktopRenderer::new(surface_format);
        renderer.init_pipelines(&device);

        self.gpu = Some(GpuState {
            device,
            queue,
            surface,
            surface_config,
            renderer,
        });
        self.window = Some(window);

        Ok(())
    }

    fn render(&mut self) {
        let Some(gpu) = &mut self.gpu else { return };
        let Some(window) = &self.window else { return };

        let size = window.inner_size();
        if size.width == 0 || size.height == 0 {
            return;
        }

        let commands = self.delegate.on_frame(0, size.width, size.height);

        let surface_texture = match gpu.surface.get_current_texture() {
            Ok(t) => t,
            Err(e) => {
                log::warn!("Surface texture error: {e}");
                return;
            }
        };

        let view = surface_texture
            .texture
            .create_view(&wgpu::TextureViewDescriptor::default());

        let mut encoder = gpu
            .device
            .create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("frame"),
            });

        gpu.renderer.render(
            &gpu.device,
            &gpu.queue,
            &mut encoder,
            &view,
            &commands,
            size.width,
            size.height,
        );

        gpu.queue.submit([encoder.finish()]);
        surface_texture.present();
    }
}

impl ApplicationHandler for App {
    fn resumed(&mut self, event_loop: &ActiveEventLoop) {
        if self.window.is_some() {
            return;
        }

        let attrs = Window::default_attributes()
            .with_title("Clone Desktop")
            .with_inner_size(LogicalSize::new(1280, 800));

        let window = Arc::new(event_loop.create_window(attrs).expect("create window"));

        if let Err(e) = self.init_gpu(window) {
            log::error!("GPU init failed: {e}");
            event_loop.exit();
        }
    }

    fn window_event(&mut self, event_loop: &ActiveEventLoop, _id: WindowId, event: WindowEvent) {
        match event {
            WindowEvent::CloseRequested => {
                event_loop.exit();
            }
            WindowEvent::Resized(size) => {
                if let Some(gpu) = &mut self.gpu {
                    gpu.surface_config.width = size.width.max(1);
                    gpu.surface_config.height = size.height.max(1);
                    gpu.surface.configure(&gpu.device, &gpu.surface_config);
                }
                if let Some(w) = &self.window {
                    w.request_redraw();
                }
            }
            WindowEvent::RedrawRequested => {
                self.render();
                if let Some(w) = &self.window {
                    w.request_redraw();
                }
            }
            WindowEvent::CursorMoved { position, .. } => {
                self.delegate.on_pointer_move(0, position.x, position.y);
                if let Some(w) = &self.window {
                    w.request_redraw();
                }
            }
            WindowEvent::MouseInput { button, state, .. } => {
                let btn = match button {
                    winit::event::MouseButton::Left => 0,
                    winit::event::MouseButton::Right => 1,
                    winit::event::MouseButton::Middle => 2,
                    _ => 3,
                };
                let pressed = state == winit::event::ElementState::Pressed;
                self.delegate.on_pointer_button(0, btn, pressed);
                if let Some(w) = &self.window {
                    w.request_redraw();
                }
            }
            WindowEvent::KeyboardInput { event, .. } => {
                if let winit::keyboard::PhysicalKey::Code(code) = event.physical_key {
                    let pressed = event.state == winit::event::ElementState::Pressed;
                    self.delegate.on_key(0, code as u32, pressed);
                    if let Some(w) = &self.window {
                        w.request_redraw();
                    }
                }
            }
            _ => {}
        }
    }
}

/// Run the event loop. Blocks the current thread.
pub fn run(delegate: Box<dyn DesktopDelegate>) -> Result<(), EngineError> {
    env_logger::try_init().ok();

    let event_loop = EventLoop::new().map_err(|e| EngineError::GpuInitFailed {
        reason: e.to_string(),
    })?;

    let mut app = App::new(delegate);
    event_loop
        .run_app(&mut app)
        .map_err(|e| EngineError::GpuInitFailed {
            reason: e.to_string(),
        })?;

    Ok(())
}
