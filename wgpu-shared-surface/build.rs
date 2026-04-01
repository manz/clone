fn main() {
    #[cfg(target_os = "macos")]
    {
        println!("cargo:rustc-link-lib=framework=IOSurface");
        println!("cargo:rustc-link-lib=framework=CoreFoundation");

        let mut build = cc::Build::new();
        build
            .file("../Sources/FFI/CPosixShim/clone_posix_shim.c")
            .include("../Sources/FFI/CPosixShim/include")
            .flag("-Wno-deprecated-declarations");
        build.compile("clone_posix_shim");
    }
}
