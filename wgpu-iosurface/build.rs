fn main() {
    println!("cargo:rustc-link-lib=framework=IOSurface");
    println!("cargo:rustc-link-lib=framework=CoreFoundation");

    // Build the C helper for sendmsg/recvmsg + Mach port transfer
    let mut build = cc::Build::new();
    build
        .file("../Sources/FFI/CPosixShim/clone_posix_shim.c")
        .include("../Sources/FFI/CPosixShim/include");

    #[cfg(target_os = "macos")]
    {
        // Suppress deprecation warning for bootstrap_register
        build.flag("-Wno-deprecated-declarations");
    }

    build.compile("clone_posix_shim");
}
