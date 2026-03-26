//! Raw FFI bindings for IOSurface framework.

use std::ffi::c_void;
use std::ptr;

/// Opaque IOSurface reference (CFType).
pub type IOSurfaceRef = *mut c_void;

// IOSurface property keys
unsafe extern "C" {
    static kIOSurfaceWidth: *const c_void;
    static kIOSurfaceHeight: *const c_void;
    static kIOSurfaceBytesPerElement: *const c_void;
    static kIOSurfacePixelFormat: *const c_void;
    static kIOSurfaceBytesPerRow: *const c_void;
}

// IOSurface functions
unsafe extern "C" {
    pub fn IOSurfaceCreate(properties: *const c_void) -> IOSurfaceRef;
    pub fn IOSurfaceGetID(surface: IOSurfaceRef) -> u32;
    pub fn IOSurfaceLookup(csid: u32) -> IOSurfaceRef;
    pub fn IOSurfaceGetWidth(surface: IOSurfaceRef) -> usize;
    pub fn IOSurfaceGetHeight(surface: IOSurfaceRef) -> usize;
    pub fn IOSurfaceGetBytesPerRow(surface: IOSurfaceRef) -> usize;
    pub fn IOSurfaceIncrementUseCount(surface: IOSurfaceRef);
    pub fn IOSurfaceDecrementUseCount(surface: IOSurfaceRef);
    /// Create a Mach port for cross-process IOSurface sharing.
    pub fn IOSurfaceCreateMachPort(surface: IOSurfaceRef) -> u32;
    /// Import an IOSurface from a Mach port received from another process.
    pub fn IOSurfaceLookupFromMachPort(port: u32) -> IOSurfaceRef;
}

// CoreFoundation types and functions
type CFTypeRef = *const c_void;
type CFStringRef = *const c_void;
type CFNumberRef = *const c_void;
type CFDictionaryRef = *const c_void;
type CFAllocatorRef = *const c_void;
type CFIndex = isize;

const K_CF_NUMBER_INT_TYPE: CFIndex = 9; // kCFNumberIntType
const K_CF_ALLOCATOR_DEFAULT: CFAllocatorRef = ptr::null();

unsafe extern "C" {
    fn CFNumberCreate(allocator: CFAllocatorRef, the_type: CFIndex, value_ptr: *const c_void) -> CFNumberRef;
    fn CFDictionaryCreate(
        allocator: CFAllocatorRef,
        keys: *const CFTypeRef,
        values: *const CFTypeRef,
        num_values: CFIndex,
        key_callbacks: *const c_void,
        value_callbacks: *const c_void,
    ) -> CFDictionaryRef;
    fn CFRelease(cf: CFTypeRef);
    static kCFTypeDictionaryKeyCallBacks: c_void;
    static kCFTypeDictionaryValueCallBacks: c_void;
}

/// BGRA pixel format constant ('BGRA' as u32 big-endian).
const PIXEL_FORMAT_BGRA: u32 = 0x42475241; // 'BGRA'

/// Create an IOSurface with the given dimensions (BGRA8, 4 bytes per pixel).
pub fn create(width: u32, height: u32) -> IOSurfaceRef {
    unsafe {
        let width_val = width as i32;
        let height_val = height as i32;
        let bpe_val: i32 = 4;
        let pixel_format_val = PIXEL_FORMAT_BGRA as i32;
        let bytes_per_row_val = (width * 4) as i32;

        let cf_width = CFNumberCreate(K_CF_ALLOCATOR_DEFAULT, K_CF_NUMBER_INT_TYPE, &width_val as *const _ as *const c_void);
        let cf_height = CFNumberCreate(K_CF_ALLOCATOR_DEFAULT, K_CF_NUMBER_INT_TYPE, &height_val as *const _ as *const c_void);
        let cf_bpe = CFNumberCreate(K_CF_ALLOCATOR_DEFAULT, K_CF_NUMBER_INT_TYPE, &bpe_val as *const _ as *const c_void);
        let cf_pixel_format = CFNumberCreate(K_CF_ALLOCATOR_DEFAULT, K_CF_NUMBER_INT_TYPE, &pixel_format_val as *const _ as *const c_void);
        let cf_bytes_per_row = CFNumberCreate(K_CF_ALLOCATOR_DEFAULT, K_CF_NUMBER_INT_TYPE, &bytes_per_row_val as *const _ as *const c_void);

        let keys: [CFTypeRef; 5] = [
            kIOSurfaceWidth as CFTypeRef,
            kIOSurfaceHeight as CFTypeRef,
            kIOSurfaceBytesPerElement as CFTypeRef,
            kIOSurfacePixelFormat as CFTypeRef,
            kIOSurfaceBytesPerRow as CFTypeRef,
        ];
        let values: [CFTypeRef; 5] = [
            cf_width as CFTypeRef,
            cf_height as CFTypeRef,
            cf_bpe as CFTypeRef,
            cf_pixel_format as CFTypeRef,
            cf_bytes_per_row as CFTypeRef,
        ];

        let dict = CFDictionaryCreate(
            K_CF_ALLOCATOR_DEFAULT,
            keys.as_ptr(),
            values.as_ptr(),
            5,
            &kCFTypeDictionaryKeyCallBacks as *const _ as *const c_void,
            &kCFTypeDictionaryValueCallBacks as *const _ as *const c_void,
        );

        let surface = IOSurfaceCreate(dict);

        // Clean up CF objects
        CFRelease(dict as CFTypeRef);
        CFRelease(cf_width as CFTypeRef);
        CFRelease(cf_height as CFTypeRef);
        CFRelease(cf_bpe as CFTypeRef);
        CFRelease(cf_pixel_format as CFTypeRef);
        CFRelease(cf_bytes_per_row as CFTypeRef);

        surface
    }
}

/// Look up an existing IOSurface by its global ID.
pub fn lookup(surface_id: u32) -> IOSurfaceRef {
    unsafe { IOSurfaceLookup(surface_id) }
}

/// Get the global ID of an IOSurface (for cross-process sharing).
pub fn get_id(surface: IOSurfaceRef) -> u32 {
    unsafe { IOSurfaceGetID(surface) }
}

/// Create a Mach port send right for cross-process sharing.
pub fn create_mach_port(surface: IOSurfaceRef) -> u32 {
    unsafe { IOSurfaceCreateMachPort(surface) }
}

/// Import an IOSurface from a Mach port.
pub fn lookup_from_mach_port(port: u32) -> IOSurfaceRef {
    unsafe { IOSurfaceLookupFromMachPort(port) }
}

// --- fileport: convert Mach port ↔ file descriptor for SCM_RIGHTS transfer ---

unsafe extern "C" {
    fn fileport_makefd(port: u32) -> i32;
    fn fileport_makeport(fd: i32, port: *mut u32) -> i32;
}

/// Convert a Mach port send right to a file descriptor (via fileport).
/// The fd can be sent to another process via SCM_RIGHTS.
pub fn mach_port_to_fd(port: u32) -> Result<i32, String> {
    let fd = unsafe { fileport_makefd(port) };
    if fd < 0 {
        Err(format!("fileport_makefd failed for port {port}"))
    } else {
        Ok(fd)
    }
}

/// Convert a file descriptor (received via SCM_RIGHTS) back to a Mach port.
pub fn fd_to_mach_port(fd: i32) -> Result<u32, String> {
    let mut port: u32 = 0;
    let result = unsafe { fileport_makeport(fd, &mut port) };
    if result != 0 || port == 0 {
        Err(format!("fileport_makeport failed for fd {fd}"))
    } else {
        Ok(port)
    }
}

/// Release an IOSurface reference.
pub fn release(surface: IOSurfaceRef) {
    if !surface.is_null() {
        unsafe { CFRelease(surface as CFTypeRef) }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn create_and_lookup() {
        let surface = create(64, 64);
        assert!(!surface.is_null());

        let id = get_id(surface);
        assert!(id > 0);

        let looked_up = lookup(id);
        assert!(!looked_up.is_null());
        assert_eq!(unsafe { IOSurfaceGetWidth(looked_up) }, 64);
        assert_eq!(unsafe { IOSurfaceGetHeight(looked_up) }, 64);

        release(looked_up);
        release(surface);
    }
}
