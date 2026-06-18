# Clone appliance image: self-contained, boots straight to the Clone desktop.
#
# Unlike clone-desktop.nix (dev: symlinks artifacts from the /mnt/clone virtiofs
# mount), this module BAKES the built artifact tree into the image so it boots
# with no host mount (the form UTM needs).
#
# The artifact tree is produced by `make os-stage` into .build/clone-root and
# read into the Nix store at eval time. Because .build is gitignored, the image
# must be built with `--impure` (see flake.nix / `make os-image`).
{ config, pkgs, lib, ... }:

let
  # Path to the staged macOS-layout tree (System/, Applications/, Library/).
  # Overridable; defaults to the in-repo build output.
  rootPath = builtins.getEnv "CLONE_ROOT_STAGE";
  cloneRoot = builtins.path {
    name = "clone-root";
    path = if rootPath != "" then rootPath else ../.build/clone-root;
  };

  compositor = "/System/Library/CoreServices/CloneDesktop";

  # GPU + C libs the baked binaries dlopen at runtime (ABI-stable, fine from nix).
  # The Swift runtime is NOT here: it's bundled from swiftly into
  # /System/Library/swift-linux by `make install` (Swift has no Linux ABI
  # stability, so it must match the toolchain that built the binaries).
  runtimeLibs = lib.makeLibraryPath [
    pkgs.libglvnd         # libEGL.so.1 / libGLESv2.so.2 dispatcher wgpu loads
    pkgs.mesa             # GL/EGL vendor driver (virgl) + libgbm + dri
    pkgs.libxkbcommon
    pkgs.wayland          # libwayland-egl for the windowed GL surface
    pkgs.fontconfig
    pkgs.freetype
    pkgs.sqlite
    pkgs.curl             # FoundationNetworking
    pkgs.libxml2          # Foundation
    pkgs.libdrm           # direct DRM/KMS server backend
    pkgs.stdenv.cc.cc.lib # libstdc++
  ];

  sessionEnv = {
    # /run/opengl-driver/lib: NixOS GL driver dir (virgl vendor + dri). Then the
    # engine .so's, the Swift runtime, and the client GL/EGL stack.
    LD_LIBRARY_PATH =
      "/run/opengl-driver/lib:/System/Library:/System/Library/swift-linux:" + runtimeLibs;
    # Empty CLONE_ROOT => paths resolve at the FS root (/System, /Applications),
    # matching the baked layout (default would be ~/.clone).
    CLONE_ROOT = "";
    # Accelerated OpenGL via virgl (real GPU through Metal); see flake/engine.
    WGPU_BACKEND = "gl";
    # cage uses its GLES renderer on virgl (confirmed: it modesets fine). No
    # hardware cursor plane under vz.
    WLR_NO_HARDWARE_CURSORS = "1";
    # winit runs as a Wayland client of cage until the direct-KMS backend lands.
    WINIT_UNIX_BACKEND = "wayland";
    FONTCONFIG_PATH = "/etc/fonts";
  };
in
{
  system.stateVersion = "24.11";

  # --- Boot (UEFI, aarch64 under UTM/QEMU) ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.availableKernelModules = [
    "virtio_pci" "virtio_blk" "virtio_net" "virtio_scsi" "virtio_gpu"
  ];
  # Serial console (aarch64 virt = ttyAMA0): boot log + a login on UTM's serial
  # terminal, which is copy-pasteable (unlike the graphical VT).
  boot.kernelParams = [ "console=tty0" "console=ttyAMA0,115200" ];

  networking.hostName = "clone";
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.dev = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "render" "input" "seat" ];
    initialPassword = "clone";
  };

  # --- GPU: Mesa with lavapipe (software Vulkan) ---
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ mesa vulkan-loader ];
  };

  # Clone binaries are generic Ubuntu-built ELFs (interp /lib/ld-linux-aarch64.so.1),
  # which NixOS lacks. nix-ld provides that loader + the base C libraries so the
  # foreign binaries run. The Swift runtime stays on LD_LIBRARY_PATH (sessionEnv).
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib   # libstdc++, libgcc_s
    zlib               # compress2 (PNG encoder)
    libglvnd mesa libxkbcommon wayland
    fontconfig freetype sqlite curl libxml2
    alsa-lib           # libasound.so.2 (cpal audio)
    libdrm             # direct DRM/KMS server backend
  ];

  # --- Bake the artifact tree into the image at /System, /Applications, /Library ---
  # Symlink from the read-only store copy so the layout matches the runtime's
  # absolute paths (/System/Library/Frameworks, etc).
  systemd.tmpfiles.rules = [
    "L+ /System          - - - - ${cloneRoot}/System"
    "L+ /Applications     - - - - ${cloneRoot}/Applications"
    "L+ /Library          - - - - ${cloneRoot}/Library"
    # App binaries (ycodebuild) embed the absolute build-staging framework path
    # as a DT_NEEDED with no SONAME, so the loader uses it verbatim. Point that
    # staging path at / so it resolves. TODO: fix ycodebuild to emit SONAME/rpath
    # and drop this shim.
    "d /mnt               0755 root root -"
    "d /mnt/clone         0755 root root -"
    "d /mnt/clone/.build  0755 root root -"
    # clone-root = install staging; sdk = ycodebuild's prebuilt framework dir.
    # App binaries embed both as absolute DT_NEEDED paths.
    "L+ /mnt/clone/.build/clone-root - - - - /"
    "L+ /mnt/clone/.build/sdk        - - - - /"
  ];

  # --- Session: cage launches the compositor fullscreen on TTY1 ---
  # services.cage owns autologin + seat (libseat) + the Wayland host.
  services.cage = {
    enable = true;
    user = "dev";
    program = compositor;
    environment = sessionEnv;
  };

  # --- Fonts ---
  fonts = {
    packages = with pkgs; [
      liberation_ttf noto-fonts iosevka
    ];
    fontconfig.defaultFonts = {
      sansSerif = [ "Liberation Sans" "Noto Sans" ];
      monospace = [ "Iosevka Fixed" "Liberation Mono" ];
    };
  };

  # Debug access: drop for a sealed release image. cage owns the seat/TTY.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
    settings.PermitRootLogin = "yes";
  };

  environment.systemPackages = with pkgs; [ vim ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
