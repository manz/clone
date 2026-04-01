use std::process::Command;

/// Test that IOSurface Mach ports work across processes.
#[test]
fn iosurface_cross_process_mach_port() {
    // Create an IOSurface in this process
    let surface = wgpu_iosurface::iosurface_create(64, 64);
    assert!(!surface.is_null());

    // Create a Mach port for cross-process sharing
    let port = wgpu_iosurface::iosurface_create_mach_port(surface);
    assert!(port != 0, "Mach port should be non-zero");

    // Verify we can look it up from the same process via the mach port
    let imported = wgpu_iosurface::iosurface_lookup_from_mach_port(port);
    assert!(!imported.is_null(), "Same-process mach port lookup should work");

    let original_id = wgpu_iosurface::iosurface_get_id(surface);
    let imported_id = wgpu_iosurface::iosurface_get_id(imported);
    assert_eq!(original_id, imported_id, "Imported IOSurface should have the same ID");

    wgpu_iosurface::iosurface_release(imported);
    wgpu_iosurface::iosurface_release(surface);
}
