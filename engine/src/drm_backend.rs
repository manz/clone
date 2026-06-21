//! Direct DRM/KMS server backend (Linux): own the display, render the compositor
//! frame via wgpu/virgl into double-buffered gbm scanout buffers, page-flip on
//! vblank. No wayland host, no GL window surface (sidesteps virgl's pbuffer-only
//! configs). Used instead of winit when no WAYLAND_DISPLAY/DISPLAY is set.

use std::fs::{File, OpenOptions};
use std::os::fd::{AsFd, AsRawFd, BorrowedFd, FromRawFd, IntoRawFd, OwnedFd, RawFd};
use std::os::unix::fs::OpenOptionsExt;
use std::path::Path;

use drm::control::{connector, Device as ControlDevice};
use drm::Device as BasicDevice;
use gbm::{BufferObject, BufferObjectFlags, Format as GbmFormat};
use input::event::{
    keyboard::KeyboardEventTrait, pointer::ButtonState, Event as InputEvent, KeyboardEvent,
    PointerEvent,
};
use input::{Libinput, LibinputInterface};

use std::sync::atomic::{AtomicBool, AtomicI32, Ordering};

use crate::ffi::{DesktopDelegate, EngineError};
use crate::render_server::RenderServer;

/// Set by SIGUSR1; the render loop dumps every app surface + the composited screen
/// to /tmp on the next frame. The graphical equivalent of F12 for the DRM backend -
/// triggerable over SSH (`kill -USR1 <compositor-pid>`) where no keyboard reaches us.
static DUMP_REQUESTED: AtomicBool = AtomicBool::new(false);

extern "C" fn on_sigusr1(_: libc::c_int) {
    DUMP_REQUESTED.store(true, Ordering::Relaxed);
}

/// Diagnostic: the compositor exits cleanly (exit 0) ~60s in and systemd restarts
/// it, bouncing back to LoginWindow. Nothing in our code exits the loop, so some
/// external SIGTERM/SIGINT is the trigger. Record the signal + SENDER pid (SA_SIGINFO)
/// so the next restart names the killer in the journal. Handler is async-signal-safe
/// (atomic stores only); the loop logs + breaks.
static TERM_REQUESTED: AtomicBool = AtomicBool::new(false);
static TERM_SIGNAL: AtomicI32 = AtomicI32::new(0);
static TERM_SENDER: AtomicI32 = AtomicI32::new(0);

extern "C" fn on_term(sig: libc::c_int, info: *mut libc::siginfo_t, _: *mut libc::c_void) {
    TERM_SIGNAL.store(sig, Ordering::Relaxed);
    let sender = if info.is_null() { -1 } else { unsafe { (*info).si_pid() } };
    TERM_SENDER.store(sender, Ordering::Relaxed);
    TERM_REQUESTED.store(true, Ordering::Relaxed);
}

/// libinput device-open hook. dev is in the `input` group, so plain O_RDWR works.
struct Input;
impl LibinputInterface for Input {
    fn open_restricted(&mut self, path: &Path, flags: i32) -> Result<OwnedFd, i32> {
        OpenOptions::new()
            .custom_flags(flags)
            .read(true)
            .write((flags & libc::O_RDWR != 0) || (flags & libc::O_WRONLY != 0))
            .open(path)
            .map(|f| f.into())
            .map_err(|e| e.raw_os_error().unwrap_or(libc::EIO))
    }
    fn close_restricted(&mut self, fd: OwnedFd) {
        drop(File::from(fd));
    }
}

/// xkbcommon keyboard state: turns raw evdev keycodes from libinput into typed
/// text (UTF-8), the way winit's `event.text` does on the windowed path. Without
/// this the DRM backend can feed `on_key` (raw scancodes) but never `on_key_char`,
/// so text fields (e.g. the LoginWindow password) get nothing typed.
struct Keyboard {
    state: xkbcommon::xkb::State,
}

impl Keyboard {
    /// Build from the system default rules/model/layout (env-overridable via the
    /// standard XKB_DEFAULT_* vars). Returns None if the keymap won't compile.
    fn new() -> Option<Self> {
        use xkbcommon::xkb;
        let ctx = xkb::Context::new(xkb::CONTEXT_NO_FLAGS);
        let keymap = xkb::Keymap::new_from_names(
            &ctx, "", "", "", "", None, xkb::KEYMAP_COMPILE_NO_FLAGS,
        )?;
        Some(Self { state: xkb::State::new(&keymap) })
    }

    /// Update modifier state for a key and, on press, return the composed text.
    /// `evdev_key` is libinput's keycode (evdev space); xkb keycodes are +8.
    /// Control keys come back as their C0 byte (Return = "\r", Backspace = "\u{8}"),
    /// which LoginWindow's `onKeyChar` already understands.
    fn process(&mut self, evdev_key: u32, pressed: bool) -> Option<String> {
        use xkbcommon::xkb::{KeyDirection, Keycode};
        let keycode = Keycode::new(evdev_key + 8);
        let text = if pressed {
            let s = self.state.key_get_utf8(keycode);
            (!s.is_empty()).then_some(s)
        } else {
            None
        };
        self.state.update_key(
            keycode,
            if pressed { KeyDirection::Down } else { KeyDirection::Up },
        );
        text
    }

    /// Active modifiers as NSEvent.ModifierFlags bits (matches the winit path in
    /// window.rs: shift 1<<17, control 1<<18, option/alt 1<<19, command/super 1<<20).
    /// Queried after `process` updates the state, so Ctrl-<key> is reflected.
    fn ns_modifiers(&self) -> u32 {
        use xkbcommon::xkb;
        let active = |name: &str| self.state.mod_name_is_active(name, xkb::STATE_MODS_EFFECTIVE);
        let mut flags: u32 = 0;
        if active(xkb::MOD_NAME_SHIFT) { flags |= 1 << 17; }
        if active(xkb::MOD_NAME_CTRL)  { flags |= 1 << 18; }
        if active(xkb::MOD_NAME_ALT)   { flags |= 1 << 19; }
        if active(xkb::MOD_NAME_LOGO)  { flags |= 1 << 20; }
        flags
    }
}

/// Classic arrow cursor (X = black outline, W = white fill, space = transparent).
const ARROW: [&str; 16] = [
    "X               ",
    "XX              ",
    "XWX             ",
    "XWWX            ",
    "XWWWX           ",
    "XWWWWX          ",
    "XWWWWWX         ",
    "XWWWWWWX        ",
    "XWWWWWWWX       ",
    "XWWWWWWWWX      ",
    "XWWWWWXXXXX     ",
    "XWWXWWX         ",
    "XWX XWWX        ",
    "XX  XWWX        ",
    "X    XWWX       ",
    "     XXX        ",
];

/// 64x64 ARGB8888 (B,G,R,A bytes) cursor image with the arrow at the top-left.
fn cursor_pixels() -> Vec<u8> {
    let mut px = vec![0u8; 64 * 64 * 4];
    for (row, line) in ARROW.iter().enumerate() {
        for (col, ch) in line.bytes().enumerate() {
            let i = (row * 64 + col) * 4;
            match ch {
                b'X' => px[i..i + 4].copy_from_slice(&[255, 255, 255, 255]), // white border
                b'W' => px[i..i + 4].copy_from_slice(&[0, 0, 0, 255]),       // black fill
                _ => {}
            }
        }
    }
    px
}

struct Card(std::fs::File);
impl AsFd for Card {
    fn as_fd(&self) -> BorrowedFd<'_> {
        self.0.as_fd()
    }
}
impl BasicDevice for Card {}
impl ControlDevice for Card {}

fn err(reason: impl ToString) -> EngineError {
    EngineError::GpuInitFailed { reason: reason.to_string() }
}

/// One scanout buffer: gbm bo + the wgpu texture aliasing it + its KMS fb.
struct Buffer {
    _bo: BufferObject<()>,
    shared: wgpu_shared_surface::SharedTexture,
    fb: drm::control::framebuffer::Handle,
}

pub fn run_drm(delegate: Box<dyn DesktopDelegate>) -> Result<(), EngineError> {
    // SIGUSR1 -> dump surfaces + composited screen on the next frame (debug capture
    // over SSH). Safe: the handler only flips an atomic.
    unsafe { libc::signal(libc::SIGUSR1, on_sigusr1 as *const () as libc::sighandler_t); }
    // SIGTERM/SIGINT -> record the sender pid so we learn who is killing us.
    unsafe {
        let mut sa: libc::sigaction = std::mem::zeroed();
        sa.sa_sigaction = on_term as usize;
        sa.sa_flags = libc::SA_SIGINFO;
        libc::sigemptyset(&mut sa.sa_mask);
        libc::sigaction(libc::SIGTERM, &sa, std::ptr::null_mut());
        libc::sigaction(libc::SIGINT, &sa, std::ptr::null_mut());
    }
    let path = std::env::var("CLONE_DRM_CARD").unwrap_or_else(|_| "/dev/dri/card0".into());
    let file = OpenOptions::new().read(true).write(true).open(&path)
        .map_err(|e| err(format!("open {path}: {e}")))?;
    let gbm = gbm::Device::new(Card(file)).map_err(|e| err(format!("gbm device: {e}")))?;
    gbm.acquire_master_lock().map_err(|e| err(format!("DRM master: {e}")))?;

    let res = gbm.resource_handles().map_err(err)?;
    let conn = res.connectors().iter()
        .filter_map(|&h| gbm.get_connector(h, false).ok())
        .find(|c| c.state() == connector::State::Connected)
        .ok_or_else(|| err("no connected connector"))?;
    let mode = *conn.modes().first().ok_or_else(|| err("connector has no modes"))?;
    let (w, h) = mode.size();
    let (w, h) = (w as u32, h as u32);
    let crtc = conn.current_encoder()
        .and_then(|e| gbm.get_encoder(e).ok())
        .and_then(|e| e.crtc())
        .or_else(|| res.crtcs().first().copied())
        .ok_or_else(|| err("no crtc"))?;
    log::info!("DRM: connector {:?} {}x{}", conn.interface(), w, h);

    // wgpu GL (surfaceless / off-screen on virgl).
    let instance = wgpu::Instance::new(wgpu::InstanceDescriptor {
        backends: wgpu::Backends::GL,
        backend_options: wgpu::BackendOptions::default(),
        flags: wgpu::InstanceFlags::empty(),
        memory_budget_thresholds: wgpu::MemoryBudgetThresholds::default(),
        display: None,
    });
    let adapter = pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions {
        power_preference: wgpu::PowerPreference::HighPerformance,
        compatible_surface: None,
        force_fallback_adapter: false,
    })).map_err(err)?;
    log::info!("DRM adapter: {}", adapter.get_info().name);
    let mut dd = wgpu::DeviceDescriptor::default();
    dd.required_limits = adapter.limits();
    let (device, queue) = pollster::block_on(adapter.request_device(&dd)).map_err(err)?;
    wgpu_shared_surface::init_egl(&adapter);

    // Linear, non-sRGB target (KMS scans out the raw bytes).
    let format = wgpu::TextureFormat::Bgra8Unorm;
    let fourcc = GbmFormat::Xrgb8888 as u32;

    let mut make_buffer = || -> Result<Buffer, EngineError> {
        let bo = gbm.create_buffer_object::<()>(
            w, h, GbmFormat::Xrgb8888,
            BufferObjectFlags::SCANOUT | BufferObjectFlags::RENDERING,
        ).map_err(|e| err(format!("gbm bo: {e}")))?;
        let dmabuf = bo.fd().map_err(|e| err(format!("bo fd: {e}")))?;
        let stride = bo.stride();
        let modifier: u64 = bo.modifier().into();
        let shared = wgpu_shared_surface::SharedTexture::from_dmabuf_render(
            &device, dmabuf.as_raw_fd(), stride, 0, fourcc, modifier, w, h, format,
        ).map_err(err)?;
        // virtio-gpu KMS rejects addfb2-with-modifiers; legacy addfb works (linear).
        let fb = gbm.add_framebuffer(&bo, 24, 32).map_err(|e| err(format!("addfb: {e}")))?;
        Ok(Buffer { _bo: bo, shared, fb })
    };
    let mut buffers = [make_buffer()?, make_buffer()?];

    let mut render_server = RenderServer::new(&device, &queue, format, format);
    let wp = delegate.wallpaper_path();
    if !wp.is_empty() {
        render_server.load_wallpaper(&device, &queue, &wp);
    }

    // KMS cursor plane: a small ARGB bo with the arrow.
    // scale=1.0: logical == physical (1280x800). Apps render at 2x and the
    // surface downscales via UV (works, click coords line up). A true HiDPI
    // scale needs the whole model (apps/hit-test/menubar-width) made consistent;
    // until then 1.0 keeps the desktop usable (menubar looks half = known issue).
    let scale = 1.0_f32;
    let mut cx = (w / 2) as f64;
    let mut cy = (h / 2) as f64;
    if let Ok(mut cbo) = gbm.create_buffer_object::<()>(
        64, 64, GbmFormat::Argb8888,
        BufferObjectFlags::CURSOR | BufferObjectFlags::WRITE,
    ) {
        let _ = cbo.write(&cursor_pixels());
        let _ = gbm.set_cursor(crtc, Some(&cbo));
        let _ = gbm.move_cursor(crtc, (cx as i32, cy as i32));
        std::mem::forget(cbo); // keep the cursor bo alive for the session
    }

    // libinput from the seat's devices.
    let mut libinput = Libinput::new_with_udev(Input);
    if libinput.udev_assign_seat("seat0").is_err() {
        log::warn!("DRM: libinput udev_assign_seat failed; no input");
    }
    let li_fd = libinput.as_raw_fd();
    let drm_fd = gbm.as_fd().as_raw_fd();

    // xkb keymap for translating evdev keycodes -> typed text (on_key_char).
    let mut keyboard = Keyboard::new();
    if keyboard.is_none() {
        log::warn!("DRM: xkb keymap failed to compile; no text input");
    }

    // First frame on buffer 0, then set_crtc to start scanout.
    let mut front = 0usize;
    render_compositor(&mut render_server, &device, &queue, &buffers[front].shared, w, h, scale, &*delegate);
    gbm.set_crtc(crtc, Some(buffers[front].fb), (0, 0), &[conn.handle()], Some(mode))
        .map_err(|e| err(format!("set_crtc: {e}")))?;

    log::info!("DRM: entering render loop");
    // Render continuously, paced by a poll timeout. NOT gated on the page-flip
    // event (virtio-gpu doesn't deliver it reliably, which made the loop only
    // advance on input -> "appears on hover"). page_flip self-throttles via
    // EBUSY while a flip is in flight; we just skip that frame.
    loop {
        if TERM_REQUESTED.load(Ordering::Relaxed) {
            log::warn!(
                "compositor: caught signal {} from pid {} - exiting render loop",
                TERM_SIGNAL.load(Ordering::Relaxed),
                TERM_SENDER.load(Ordering::Relaxed)
            );
            break;
        }
        // Pace ~60fps + wake immediately on input; drain input + any flip events.
        let mut fds = [
            libc::pollfd { fd: drm_fd, events: libc::POLLIN, revents: 0 },
            libc::pollfd { fd: li_fd, events: libc::POLLIN, revents: 0 },
        ];
        unsafe { libc::poll(fds.as_mut_ptr(), 2, 16) };
        if fds[1].revents & libc::POLLIN != 0 {
            let _ = libinput.dispatch();
            while let Some(ev) = libinput.next() {
                handle_input(ev, &*delegate, &mut cx, &mut cy, w, h, scale, &gbm, crtc, &mut keyboard);
            }
        }
        if fds[0].revents & libc::POLLIN != 0 {
            let _ = gbm.receive_events().map(|evs| evs.count());
        }

        let back = front ^ 1;
        render_compositor(&mut render_server, &device, &queue, &buffers[back].shared, w, h, scale, &*delegate);
        // EBUSY while the previous flip is pending -> skip (don't swap front).
        if gbm.page_flip(crtc, buffers[back].fb, drm::control::PageFlipFlags::EVENT, None).is_ok() {
            front = back;
        }
    }
    Ok(())
}

/// Map a libinput event to a delegate callback; move the KMS cursor.
#[allow(clippy::too_many_arguments)]
fn handle_input(
    ev: InputEvent,
    delegate: &dyn DesktopDelegate,
    cx: &mut f64,
    cy: &mut f64,
    w: u32,
    h: u32,
    scale: f32,
    gbm: &gbm::Device<Card>,
    crtc: drm::control::crtc::Handle,
    keyboard: &mut Option<Keyboard>,
) {
    // cx/cy are PHYSICAL screen coords (cursor plane); the delegate hit-tests in
    // LOGICAL coords, so divide by scale for on_pointer_move (matches winit path).
    let s = scale as f64;
    match ev {
        InputEvent::Pointer(PointerEvent::Motion(m)) => {
            *cx = (*cx + m.dx()).clamp(0.0, (w - 1) as f64);
            *cy = (*cy + m.dy()).clamp(0.0, (h - 1) as f64);
            let _ = gbm.move_cursor(crtc, (*cx as i32, *cy as i32));
            delegate.on_pointer_move(0, *cx / s, *cy / s);
        }
        // VMs expose an absolute pointing device (tablet); handle those too.
        InputEvent::Pointer(PointerEvent::MotionAbsolute(m)) => {
            *cx = m.absolute_x_transformed(w).clamp(0.0, (w - 1) as f64);
            *cy = m.absolute_y_transformed(h).clamp(0.0, (h - 1) as f64);
            let _ = gbm.move_cursor(crtc, (*cx as i32, *cy as i32));
            delegate.on_pointer_move(0, *cx / s, *cy / s);
        }
        InputEvent::Pointer(PointerEvent::Button(b)) => {
            let btn = match b.button() {
                0x110 => 0, // BTN_LEFT
                0x111 => 1, // BTN_RIGHT
                0x112 => 2, // BTN_MIDDLE
                _ => 3,
            };
            let pressed = b.button_state() == ButtonState::Pressed;
            delegate.on_pointer_button(0, btn, pressed);
        }
        InputEvent::Pointer(PointerEvent::ScrollWheel(s)) => {
            use input::event::pointer::{Axis, PointerScrollEvent};
            let dx = if s.has_axis(Axis::Horizontal) { s.scroll_value(Axis::Horizontal) } else { 0.0 };
            let dy = if s.has_axis(Axis::Vertical) { s.scroll_value(Axis::Vertical) } else { 0.0 };
            delegate.on_scroll(0, dx, dy);
        }
        InputEvent::Keyboard(KeyboardEvent::Key(k)) => {
            let pressed = k.key_state() == input::event::keyboard::KeyState::Pressed;
            if let Some(kbd) = keyboard.as_mut() {
                // process() updates xkb state first, so the modifiers we report to
                // on_key reflect this key (e.g. Ctrl-<key>). Then feed typed text.
                let text = kbd.process(k.key(), pressed);
                delegate.on_key(0, k.key(), kbd.ns_modifiers(), pressed);
                if let Some(text) = text {
                    delegate.on_key_char(0, text);
                }
            } else {
                delegate.on_key(0, k.key(), 0, pressed);
            }
        }
        _ => {}
    }
}

fn render_compositor(
    render_server: &mut RenderServer,
    device: &wgpu::Device,
    queue: &wgpu::Queue,
    target: &wgpu_shared_surface::SharedTexture,
    w: u32,
    h: u32,
    scale: f32,
    delegate: &dyn DesktopDelegate,
) {
    // Debug: clear to magenta instead of compositing, to verify the render-loop
    // + page-flip path displays at all (CLONE_DRM_DEBUG_CLEAR=1).
    if std::env::var_os("CLONE_DRM_DEBUG_CLEAR").is_some() {
        let mut enc = device.create_command_encoder(&Default::default());
        {
            let _pass = enc.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("debug_clear"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: target.view(),
                    resolve_target: None,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(wgpu::Color { r: 0.8, g: 0.0, b: 0.8, a: 1.0 }),
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
        queue.submit([enc.finish()]);
        device.poll(wgpu::PollType::wait_indefinitely()).ok();
        return;
    }
    let logical_w = (w as f32 / scale) as u32;
    let logical_h = (h as f32 / scale) as u32;
    let frames = delegate.on_composite_frame(logical_w, logical_h);
    render_server.render_frame(device, queue, target.view(), w, h, scale, &frames);

    if DUMP_REQUESTED.swap(false, Ordering::Relaxed) {
        let mut out = format!(
            "Frame: {logical_w}x{logical_h} (physical {w}x{h}, scale {scale})\nSurfaces: {}\n\n",
            frames.len()
        );
        for sf in &frames {
            out.push_str(&format!(
                "Surface {} @ ({}, {}) {}x{} content {}x{} r={} a={} - {} commands\n",
                sf.desc.surface_id, sf.desc.x, sf.desc.y, sf.desc.width, sf.desc.height,
                sf.desc.content_width, sf.desc.content_height,
                sf.desc.corner_radius, sf.desc.opacity, sf.commands.len()
            ));
        }
        let _ = std::fs::write("/tmp/clone-frame-dump.txt", &out);
        for sf in &frames {
            let path = format!("/tmp/clone-surface-{}.png", sf.desc.surface_id);
            render_server.compositor.dump_surface(sf.desc.surface_id, device, queue, &path);
        }
        dump_texture(target.texture(), device, queue, w, h, "/tmp/clone-screen.png");
        log::info!("SIGUSR1: dumped {} surfaces + screen to /tmp", frames.len());
    }

    device.poll(wgpu::PollType::wait_indefinitely()).ok();
}

/// Read back a COPY_SRC texture (BGRA8) and write it as an RGBA PNG. Used for the
/// SIGUSR1 composited-screen capture.
fn dump_texture(
    texture: &wgpu::Texture,
    device: &wgpu::Device,
    queue: &wgpu::Queue,
    width: u32,
    height: u32,
    path: &str,
) {
    let bytes_per_row = (width * 4 + 255) & !255;
    let staging = device.create_buffer(&wgpu::BufferDescriptor {
        label: Some("screen_readback"),
        size: (bytes_per_row * height) as u64,
        usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
        mapped_at_creation: false,
    });
    let mut encoder = device.create_command_encoder(&Default::default());
    encoder.copy_texture_to_buffer(
        wgpu::TexelCopyTextureInfo {
            texture,
            mip_level: 0,
            origin: wgpu::Origin3d::ZERO,
            aspect: wgpu::TextureAspect::All,
        },
        wgpu::TexelCopyBufferInfo {
            buffer: &staging,
            layout: wgpu::TexelCopyBufferLayout {
                offset: 0,
                bytes_per_row: Some(bytes_per_row),
                rows_per_image: Some(height),
            },
        },
        wgpu::Extent3d { width, height, depth_or_array_layers: 1 },
    );
    queue.submit([encoder.finish()]);

    let slice = staging.slice(..);
    let (tx, rx) = std::sync::mpsc::channel();
    slice.map_async(wgpu::MapMode::Read, move |r| { let _ = tx.send(r); });
    device.poll(wgpu::PollType::wait_indefinitely()).ok();
    let _ = rx.recv();

    let data = slice.get_mapped_range();
    let mut rgba = Vec::with_capacity((width * height * 4) as usize);
    for row in 0..height {
        let start = (row * bytes_per_row) as usize;
        for col in 0..width {
            let i = start + (col * 4) as usize;
            rgba.push(data[i + 2]);
            rgba.push(data[i + 1]);
            rgba.push(data[i]);
            rgba.push(data[i + 3]);
        }
    }
    drop(data);
    staging.unmap();

    if let Ok(file) = std::fs::File::create(path) {
        let w = std::io::BufWriter::new(file);
        let mut encoder = image::codecs::png::PngEncoder::new(w);
        use image::ImageEncoder;
        let _ = encoder.write_image(&rgba, width, height, image::ExtendedColorType::Rgba8);
    }
}
