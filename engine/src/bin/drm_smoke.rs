//! DRM/KMS smoke test: own the screen directly (no wayland host) and page-flip
//! a solid color via a dumb buffer. Proves the server-mode display path.
//!
//! Run on the VM console as root with cage stopped (so the DRM master is free):
//!   systemctl --user stop cage-tty1 ; sudo drm-smoke
//! Screen should turn solid teal for ~5s.

#[cfg(not(target_os = "linux"))]
fn main() {
    eprintln!("drm-smoke is Linux-only");
}

#[cfg(target_os = "linux")]
fn main() {
    use std::fs::OpenOptions;
    use std::os::fd::{AsFd, BorrowedFd};

    use drm::control::Device as ControlDevice;
    use drm::Device as BasicDevice;

    /// Minimal DRM device wrapper (owns the card fd).
    struct Card(std::fs::File);
    impl AsFd for Card {
        fn as_fd(&self) -> BorrowedFd<'_> {
            self.0.as_fd()
        }
    }
    impl BasicDevice for Card {}
    impl ControlDevice for Card {}

    let path = std::env::args().nth(1).unwrap_or_else(|| "/dev/dri/card0".into());
    let file = OpenOptions::new()
        .read(true)
        .write(true)
        .open(&path)
        .unwrap_or_else(|e| panic!("open {path}: {e}"));
    let card = Card(file);

    // Become DRM master (fails if another process holds it, e.g. cage running).
    card.acquire_master_lock().expect("acquire DRM master (stop cage first?)");

    let res = card.resource_handles().expect("resource_handles");

    // First connected connector + its preferred mode.
    let conn = res
        .connectors()
        .iter()
        .filter_map(|&h| card.get_connector(h, false).ok())
        .find(|c| c.state() == drm::control::connector::State::Connected)
        .expect("no connected connector");
    let mode = *conn.modes().first().expect("connector has no modes");
    let (w, h) = mode.size();
    println!("connector {:?}: {}x{}", conn.interface(), w, h);

    // A CRTC: via the connector's current encoder, else the first.
    let crtc = conn
        .current_encoder()
        .and_then(|e| card.get_encoder(e).ok())
        .and_then(|e| e.crtc())
        .or_else(|| res.crtcs().first().copied())
        .expect("no crtc");

    // Dumb buffer, fill teal (XRGB8888: 0x00_RR_GG_BB).
    let mut db = card
        .create_dumb_buffer((w as u32, h as u32), drm::buffer::DrmFourcc::Xrgb8888, 32)
        .expect("create_dumb_buffer");
    {
        let mut map = card.map_dumb_buffer(&mut db).expect("map_dumb_buffer");
        for px in map.as_mut().chunks_exact_mut(4) {
            px[0] = 0x80; // B
            px[1] = 0x80; // G
            px[2] = 0x00; // R
            px[3] = 0x00; // X
        }
    }
    let fb = card.add_framebuffer(&db, 24, 32).expect("add_framebuffer");

    card.set_crtc(crtc, Some(fb), (0, 0), &[conn.handle()], Some(mode))
        .expect("set_crtc");
    println!("modeset OK (teal for 5s)");
    std::thread::sleep(std::time::Duration::from_secs(5));

    card.destroy_framebuffer(fb).ok();
    card.destroy_dumb_buffer(db).ok();
}
