mod clone_posix_shim_sys {
    unsafe extern "C" {
        pub fn clone_mach_register_port(name: *const std::ffi::c_char, out_recv_port: *mut u32) -> i32;
        pub fn clone_mach_lookup_port(name: *const std::ffi::c_char, out_send_port: *mut u32) -> i32;
        pub fn clone_mach_send_port(dest_port: u32, port_to_send: u32) -> i32;
        pub fn clone_mach_recv_port(recv_port: u32, out_port: *mut u32) -> i32;
    }
}

/// Test bootstrap server Mach port transfer with IOSurface.
/// Uses threads to simulate app (sender) and compositor (receiver).
#[test]
fn mach_port_bootstrap_transfer() {
    use std::ffi::CString;
    use std::sync::mpsc;
    use std::thread;

    // 1. Create IOSurface and get its Mach port
    let surface = wgpu_iosurface::iosurface_create(64, 64);
    assert!(!surface.is_null());
    let original_id = wgpu_iosurface::iosurface_get_id(surface);
    let iosurface_port = wgpu_iosurface::iosurface_create_mach_port(surface);
    assert!(iosurface_port != 0);

    let name = CString::new(format!("com.clone.test.surfaces.{}", std::process::id())).unwrap();

    // 2. Register a receive port (compositor side)
    let mut recv_port: u32 = 0;
    let result = unsafe { clone_posix_shim_sys::clone_mach_register_port(name.as_ptr(), &mut recv_port) };
    assert_eq!(result, 0, "bootstrap_register should succeed");

    // 3. Sender thread (app side)
    let name_clone = name.clone();
    let (tx, rx) = mpsc::channel();
    let sender = thread::spawn(move || {
        let mut send_port: u32 = 0;
        let result = unsafe { clone_posix_shim_sys::clone_mach_lookup_port(name_clone.as_ptr(), &mut send_port) };
        assert_eq!(result, 0, "bootstrap_look_up should succeed");

        tx.send(()).unwrap(); // signal ready

        let result = unsafe { clone_posix_shim_sys::clone_mach_send_port(send_port, iosurface_port) };
        assert_eq!(result, 0, "mach_msg send should succeed");
    });

    // Wait for sender to look up the port
    rx.recv().unwrap();

    // 4. Receive (compositor side) — blocks until message arrives
    let mut received_port: u32 = 0;
    let result = unsafe { clone_posix_shim_sys::clone_mach_recv_port(recv_port, &mut received_port) };
    assert_eq!(result, 0, "mach_msg recv should succeed");
    assert!(received_port != 0);

    sender.join().unwrap();

    // 5. Import IOSurface from the received port
    let imported = wgpu_iosurface::iosurface_lookup_from_mach_port(received_port);
    assert!(!imported.is_null(), "IOSurface import from transferred Mach port should work");

    let imported_id = wgpu_iosurface::iosurface_get_id(imported);
    assert_eq!(original_id, imported_id);

    wgpu_iosurface::iosurface_release(imported);
    wgpu_iosurface::iosurface_release(surface);
}
