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
    pkgs.vulkan-loader
    pkgs.mesa             # lavapipe (lvp) software Vulkan
    pkgs.libxkbcommon
    pkgs.wayland
    pkgs.fontconfig
    pkgs.freetype
    pkgs.sqlite
    pkgs.curl             # FoundationNetworking
    pkgs.libxml2          # Foundation
    pkgs.stdenv.cc.cc.lib # libstdc++
  ];

  sessionEnv = {
    LD_LIBRARY_PATH = "/System/Library/swift-linux:" + runtimeLibs;
    # Software Vulkan via Mesa lavapipe (no GPU accel needed).
    WGPU_BACKEND = "vulkan";
    VK_ICD_FILENAMES = "${pkgs.mesa}/share/vulkan/icd.d/lvp_icd.aarch64.json";
    LIBGL_ALWAYS_SOFTWARE = "1";
    # winit runs as a Wayland client of cage until the direct-KMS backend lands.
    WINIT_UNIX_BACKEND = "wayland";
    FONTCONFIG_PATH = "/etc/fonts";
    CLONE_FRAMEWORKS_PATH = "/System/Library/Frameworks";
    CLONE_APPLICATIONS_PATH = "/Applications";
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

  # --- Bake the artifact tree into the image at /System, /Applications, /Library ---
  # Symlink from the read-only store copy so the layout matches the runtime's
  # absolute paths (CLONE_FRAMEWORKS_PATH=/System/Library/Frameworks, etc).
  systemd.tmpfiles.rules = [
    "L+ /System          - - - - ${cloneRoot}/System"
    "L+ /Applications     - - - - ${cloneRoot}/Applications"
    "L+ /Library          - - - - ${cloneRoot}/Library"
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
      liberation_ttf noto-fonts noto-fonts-emoji iosevka
    ];
    fontconfig.defaultFonts = {
      sansSerif = [ "Liberation Sans" "Noto Sans" ];
      monospace = [ "Iosevka Fixed" "Liberation Mono" ];
    };
  };

  # Debug access: drop for a sealed release image. cage owns the seat/TTY.
  services.openssh.enable = true;

  environment.systemPackages = with pkgs; [ vim vulkan-tools mesa-demos ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
