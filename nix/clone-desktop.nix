# Clone desktop session — launches the compositor as a systemd user service
{ config, pkgs, lib, ... }:

{
  # Create /Applications and /System/Library/Frameworks directories
  systemd.tmpfiles.rules = [
    "d /Applications 0755 root root -"
    "d /System 0755 root root -"
    "d /System/Library 0755 root root -"
    "d /System/Library/Frameworks 0755 root root -"
  ];

  # Clone desktop session — starts on TTY1 after auto-login
  # The compositor talks directly to DRM/KMS via winit
  systemd.user.services.clone-desktop = {
    description = "Clone Desktop Compositor";
    wantedBy = [ "default.target" ];
    after = [ "graphical-session-pre.target" ];

    environment = {
      # wgpu backend selection — Vulkan via Mesa virtio-gpu
      WGPU_BACKEND = "vulkan";
      # Wayland/DRM — winit backend for direct rendering
      WINIT_UNIX_BACKEND = "wayland";
      # Vulkan ICD loader
      VK_ICD_FILENAMES = "${pkgs.mesa}/share/vulkan/icd.d/radeon_icd.aarch64.json:${pkgs.mesa}/share/vulkan/icd.d/lvp_icd.aarch64.json";
      # Fonts
      FONTCONFIG_PATH = "/etc/fonts";
      # Clone-specific
      CLONE_FRAMEWORKS_PATH = "/System/Library/Frameworks";
      CLONE_APPLICATIONS_PATH = "/Applications";
    };

    serviceConfig = {
      ExecStart = "/Applications/CloneDesktop.app/Contents/Linux/CloneDesktop";
      Restart = "on-failure";
      RestartSec = 2;
      # Give access to DRM/GPU
      SupplementaryGroups = [ "video" "render" ];
    };
  };

  # Symlink SDK frameworks into /System/Library/Frameworks at activation time.
  # In production these come from the clone-sdk package; during dev they're
  # built from /mnt/clone/.build/sdk/.
  system.activationScripts.clone-sdk = ''
    if [ -d /mnt/clone/.build/sdk/System/Library/Frameworks ]; then
      for fw in /mnt/clone/.build/sdk/System/Library/Frameworks/*.framework; do
        name=$(basename "$fw")
        ln -sfn "$fw" "/System/Library/Frameworks/$name"
      done
      echo "Linked Clone SDK frameworks from /mnt/clone"
    fi
  '';

  # Symlink app bundles into /Applications at activation time.
  # During dev, app bundles are assembled by `make bundles` into
  # /mnt/clone/.build/bundles/*.app.
  system.activationScripts.clone-apps = ''
    if [ -d /mnt/clone/.build/bundles ]; then
      for app in /mnt/clone/.build/bundles/*.app; do
        name=$(basename "$app")
        ln -sfn "$app" "/Applications/$name"
      done
      echo "Linked Clone apps from /mnt/clone"
    fi
  '';
}
