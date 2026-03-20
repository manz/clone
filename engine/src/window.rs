use std::sync::Arc;

use winit::application::ApplicationHandler;
use winit::dpi::LogicalSize;
use winit::event::WindowEvent;
use winit::event_loop::{ActiveEventLoop, EventLoop};
use winit::window::{Window, WindowId};

use crate::ffi::{DesktopDelegate, EngineError};
use crate::renderer::DesktopRenderer;
use crate::surface_compositor::{CompositeWindow, SurfaceCompositor};

struct GpuState {
    device: wgpu::Device,
    queue: wgpu::Queue,
    surface: wgpu::Surface<'static>,
    surface_config: wgpu::SurfaceConfiguration,
    renderer: DesktopRenderer,
    compositor: SurfaceCompositor,
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
        renderer.init_pipelines(&device, &queue);

        let compositor = SurfaceCompositor::new(&device, surface_format);

        let wallpaper_path = self.delegate.wallpaper_path();
        if !wallpaper_path.is_empty() {
            renderer.load_wallpaper(&device, &queue, &wallpaper_path);
        }

        self.gpu = Some(GpuState {
            device,
            queue,
            surface,
            surface_config,
            renderer,
            compositor,
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

        // Ensure offscreen textures exist for each surface
        let mut active_ids: Vec<u64> = Vec::new();
        for sf in &surface_frames {
            let phys_w = (sf.desc.width * scale) as u32;
            let phys_h = (sf.desc.height * scale) as u32;
            gpu.compositor.ensure_surface(&gpu.device, sf.desc.surface_id, phys_w, phys_h);
            active_ids.push(sf.desc.surface_id);
        }
        gpu.compositor.gc(&active_ids);

        // Render each surface's commands into its offscreen texture
        for sf in &surface_frames {
            // Overlays (dock, menubar) have semi-transparent backgrounds
            // and need transparent clear so they don't obscure content below.
            let has_transparent_bg = sf.commands.first().map_or(true, |cmd| {
                match cmd {
                    crate::commands::RenderCommand::Rect { color, .. } |
                    crate::commands::RenderCommand::RoundedRect { color, .. } => color.a < 1.0,
                    _ => true,
                }
            });
            gpu.compositor.render_to_surface(
                sf.desc.surface_id,
                &mut gpu.renderer,
                &gpu.device,
                &gpu.queue,
                &sf.commands,
                scale,
                has_transparent_bg,
            );
        }

        // Composite onto screen
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

        // Clear screen
        {
            let mut encoder = gpu.device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("screen_clear"),
            });
            {
                let _pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                    label: Some("screen_clear_pass"),
                    color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                        view: &screen_view,
                        resolve_target: None,
                        ops: wgpu::Operations {
                            load: wgpu::LoadOp::Clear(wgpu::Color {
                                r: 0.0, g: 0.0, b: 0.0, a: 1.0,
                            }),
                            store: wgpu::StoreOp::Store,
                        },
                        depth_slice: None,
                    })],
                    depth_stencil_attachment: None,
                    timestamp_writes: None,
                    occlusion_query_set: None,
                    multiview_mask: None,
                });
            }
            gpu.queue.submit([encoder.finish()]);
        }

        // Composite surfaces back-to-front (each submitted separately)
        let composite_windows: Vec<CompositeWindow> = surface_frames
            .iter()
            .map(|sf| CompositeWindow {
                surface_id: sf.desc.surface_id,
                x: sf.desc.x * scale,
                y: sf.desc.y * scale,
                width: sf.desc.width * scale,
                height: sf.desc.height * scale,
                corner_radius: sf.desc.corner_radius * scale,
                opacity: sf.desc.opacity,
            })
            .collect();

        gpu.compositor.composite(
            &gpu.device,
            &gpu.queue,
            &screen_view,
            physical_size.width,
            physical_size.height,
            &composite_windows,
        );
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
            WindowEvent::KeyboardInput { event, .. } => {
                if let winit::keyboard::PhysicalKey::Code(code) = event.physical_key {
                    let pressed = event.state == winit::event::ElementState::Pressed;
                    if code == winit::keyboard::KeyCode::F12 && pressed {
                        self.dump_next_frame = true;
                        log::info!("Will dump next frame to /tmp/clone-frame-dump.txt");
                    }
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
