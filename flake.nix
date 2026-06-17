{
  description = "Clone (Aquax) — macOS desktop environment for Linux";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Swift toolchain for Linux
    swift-nix = {
      url = "github:stevapple/swift-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Image builder (qcow-efi for UTM, etc.)
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, swift-nix, nixos-generators }: let
    system = "aarch64-linux";
    overlayModule = { nixpkgs.overlays = [ swift-nix.overlays.default ]; };
    pkgs = import nixpkgs {
      inherit system;
      overlays = [ swift-nix.overlays.default ];
    };
  in {
    # NixOS dev VM: builds Clone from the /mnt/clone virtiofs mount.
    nixosConfigurations.clone = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        overlayModule
        ./nix/configuration.nix
        ./nix/clone-desktop.nix
      ];
    };

    # Appliance: self-contained, boots straight to Clone (artifacts baked in).
    nixosConfigurations.appliance = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [ overlayModule ./nix/appliance.nix ];
    };

    # Bootable disk image for UTM (qcow2 + EFI). Build with --impure because the
    # baked artifact tree lives in the gitignored .build/clone-root:
    #   make os-stage && make os-image   (run inside the aarch64-linux VM)
    packages.${system}.image = nixos-generators.nixosGenerate {
      inherit system;
      format = "qcow-efi";
      modules = [ overlayModule ./nix/appliance.nix ];
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
