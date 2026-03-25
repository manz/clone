use std::sync::Arc;

use winit::application::ApplicationHandler;
use winit::dpi::LogicalSize;
use winit::event::WindowEvent;
use winit::event_loop::{ActiveEventLoop, EventLoop};
use winit::window::{Window, WindowId};

use crate::ffi::{DesktopDelegate, EngineError};
use crate::render_server::RenderServer;

struct GpuState {
    device: wgpu::Device,
    queue: wgpu::Queue,
    surface: wgpu::Surface<'static>,
    surface_config: wgpu::SurfaceConfiguration,
    render_server: RenderServer,
}

struct App {
    delegate: Arc<dyn DesktopDelegate>,
    window: Option<Arc<Window>>,
    gpu: Option<GpuState>,
    dump_next_frame: bool,
}

impl App {
    fn new(delegate: Box<dyn DesktopDelegate>) -> Self {
        Self {
            delegate: Arc::from(delegate),
            window: None,
            gpu: None,
            dump_next_frame: false,
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
        // Screen surface: sRGB for correct display gamma.
        // Offscreen textures: linear (Unorm) so sRGB color values from Swift are stored as-is.
        // The compositor pipeline reads linear offscreen → writes sRGB screen.
        let screen_format = caps
            .formats
            .iter()
            .find(|f| f.is_srgb())
            .copied()
            .unwrap_or(caps.formats[0]);
        let offscreen_format = match screen_format {
            wgpu::TextureFormat::Bgra8UnormSrgb => wgpu::TextureFormat::Bgra8Unorm,
            wgpu::TextureFormat::Rgba8UnormSrgb => wgpu::TextureFormat::Rgba8Unorm,
            other => other,
        };
        log::info!("Screen format: {:?}, offscreen: {:?}, all: {:?}", screen_format, offscreen_format, caps.formats);

        let size = window.inner_size();
        let surface_config = wgpu::SurfaceConfiguration {
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
            format: screen_format,
            view_formats: vec![],
            alpha_mode: wgpu::CompositeAlphaMode::Auto,
            width: size.width.max(1),
            height: size.height.max(1),
            desired_maximum_frame_latency: 2,
            present_mode: wgpu::PresentMode::AutoVsync,
        };
        surface.configure(&device, &surface_config);

        let mut render_server = RenderServer::new(&device, &queue, offscreen_format, screen_format);

        let wallpaper_path = self.delegate.wallpaper_path();
        if !wallpaper_path.is_empty() {
            render_server.load_wallpaper(&device, &queue, &wallpaper_path);
        }

        self.gpu = Some(GpuState {
            device,
            queue,
            surface,
            surface_config,
            render_server,
        });
        self.window = Some(window);

        Ok(())
    }

    fn render(&mut self) {
        let Some(gpu) = &mut self.gpu else { return };
        let Some(window) = &self.window else { return };

        let physical_size = window.inner_size();
        if physical_size.width == 0 || physical_size.height == 0 {
            return;
        }

        let scale = window.scale_factor() as f32;
        let logical_w = (physical_size.width as f32 / scale) as u32;
        let logical_h = (physical_size.height as f32 / scale) as u32;

        // Ask Swift for per-surface frames
        let surface_frames = self.delegate.on_composite_frame(logical_w, logical_h);

        // F12 frame dump (debug concern of the event loop)
        let do_dump = self.dump_next_frame;
        if self.dump_next_frame {
            self.dump_next_frame = false;
            let path = "/tmp/clone-frame-dump.txt";
            let mut out = String::new();
            out.push_str(&format!(
                "Frame: {}x{} (physical {}x{}, scale {})\nSurfaces: {}\n\n",
                logical_w, logical_h, physical_size.width, physical_size.height,
                scale, surface_frames.len()
            ));
            for sf in &surface_frames {
                out.push_str(&format!(
                    "Surface {} @ ({}, {}) {}x{} r={} a={} — {} commands\n",
                    sf.desc.surface_id, sf.desc.x, sf.desc.y,
                    sf.desc.width, sf.desc.height,
                    sf.desc.corner_radius, sf.desc.opacity,
                    sf.commands.len()
                ));
                for (i, cmd) in sf.commands.iter().enumerate() {
                    out.push_str(&format!("  [{:3}] {:?}\n", i, cmd));
                }
                out.push_str("\n");
            }
            let _ = std::fs::write(path, &out);
            log::info!("Dumped {} surfaces to {}", surface_frames.len(), path);
        }

        // Get screen texture
        let surface_texture = match gpu.surface.get_current_texture() {
            Ok(t) => t,
            Err(e) => {
                log::warn!("Surface texture error: {e}");
                return;
            }
        };

        let screen_view = surface_texture
            .texture
            .create_view(&wgpu::TextureViewDescriptor::default());

        gpu.render_server.render_frame(
            &gpu.device,
            &gpu.queue,
            &screen_view,
            physical_size.width,
            physical_size.height,
            scale,
            &surface_frames,
        );

        // Dump surface textures to PNG on F12
        if do_dump {
            for (i, sf) in surface_frames.iter().enumerate() {
                let path = format!("/tmp/clone-surface-{}.png", sf.desc.surface_id);
                gpu.render_server.compositor.dump_surface(
                    sf.desc.surface_id, &gpu.device, &gpu.queue, &path
                );
            }
            // Also dump the glyph atlas
            gpu.render_server.renderer.dump_atlas("/tmp/clone-atlas.png");
        }

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
                let scale = self.window.as_ref().map(|w| w.scale_factor()).unwrap_or(1.0);
                self.delegate.on_pointer_move(0, position.x / scale, position.y / scale);
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
            WindowEvent::MouseWheel { delta, .. } => {
                let (dx, dy) = match delta {
                    winit::event::MouseScrollDelta::LineDelta(x, y) => (x as f64 * 20.0, y as f64 * 20.0),
                    winit::event::MouseScrollDelta::PixelDelta(pos) => (pos.x, pos.y),
                };
                self.delegate.on_scroll(0, dx, dy);
                if let Some(w) = &self.window {
                    w.request_redraw();
                }
            }
            WindowEvent::KeyboardInput { event, .. } => {
                if let winit::keyboard::PhysicalKey::Code(code) = event.physical_key {
                    let pressed = event.state == winit::event::ElementState::Pressed;
                    if code == winit::keyboard::KeyCode::F12 && pressed {
                        self.dump_next_frame = true;
                        log::info!("Will dump next frame to /tmp/clone-frame-dump.txt");
                    }
                    self.delegate.on_key(0, code as u32, pressed);
                }
                // Forward character input (text typed events)
                if event.state == winit::event::ElementState::Pressed {
                    if let Some(text) = &event.text {
                        let s = text.to_string();
                        if !s.is_empty() {
                            self.delegate.on_key_char(0, s);
                        }
                    }
                }
                if let Some(w) = &self.window {
                    w.request_redraw();
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
