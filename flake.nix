{
  description = "Clone (Aquax) — macOS desktop environment for Linux";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Swift toolchain for Linux
    swift-nix = {
      url = "github:stevapple/swift-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, swift-nix }: let
    system = "aarch64-linux";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [ swift-nix.overlays.default ];
    };
  in {
    # NixOS VM configuration — boots straight into Clone desktop
    nixosConfigurations.clone = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./nix/configuration.nix
        ./nix/clone-desktop.nix
      ];
    };

    # Dev shell for building Clone inside the VM
    devShells.${system}.default = pkgs.mkShell {
      name = "clone-dev";
      packages = with pkgs; [
        # Swift
        swift
        swiftPackageManager
        # Rust
        rustc
        cargo
        # wgpu deps
        vulkan-loader
        vulkan-headers
        vulkan-tools
        mesa
        libxkbcommon
        wayland
        wayland-protocols
        # Audio
        pipewire
        pipewire.pulse
        alsa-lib
        # Build tools
        pkg-config
        cmake
        sqlite
        # Fonts
        fontconfig
        freetype
        liberation_ttf
        noto-fonts
      ];

      LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
        pkgs.vulkan-loader
        pkgs.mesa
        pkgs.libxkbcommon
        pkgs.wayland
        pkgs.pipewire
        pkgs.alsa-lib
      ];

      VULKAN_SDK = "${pkgs.vulkan-headers}";
    };
  };
}
