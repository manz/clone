# Base NixOS configuration for the Clone VM
{ config, pkgs, lib, ... }:

{
  system.stateVersion = "24.11";

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Kernel — enable virtio for VM
  boot.initrd.availableKernelModules = [
    "virtio_pci" "virtio_blk" "virtio_net" "virtio_scsi"
    "virtio_gpu" "virtiofs"
  ];

  # Filesystem — virtiofs mount for shared source
  fileSystems."/mnt/clone" = {
    device = "clone";
    fsType = "virtiofs";
    options = [ "nofail" ];
  };

  # Networking
  networking.hostName = "clone-vm";
  networking.networkmanager.enable = true;

  # User
  users.users.dev = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "audio" "render" ];
    initialPassword = "clone";
    shell = pkgs.zsh;
  };

  # Locale
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";

  # Enable zsh
  programs.zsh.enable = true;

  # GPU — Mesa with Vulkan (virtio-gpu / virgl)
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      mesa
      vulkan-loader
    ];
  };

  # Audio — PipeWire
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Fonts — system font set
  fonts = {
    packages = with pkgs; [
      liberation_ttf
      noto-fonts
      noto-fonts-emoji
      iosevka
      helvetica-neue-lt-std  # Closest to Helvetica Neue on NixOS
    ];
    fontconfig.defaultFonts = {
      sansSerif = [ "Helvetica Neue" "Liberation Sans" "Noto Sans" ];
      monospace = [ "Iosevka Fixed" "Liberation Mono" ];
    };
  };

  # Essential packages
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    mesa-demos  # glxinfo, vulkaninfo for debugging GPU
    vulkan-tools
  ];

  # SSH for remote build access from macOS
  services.openssh.enable = true;

  # Auto-login to dev user (no display manager — Clone IS the session)
  services.getty.autologinUser = "dev";

  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
