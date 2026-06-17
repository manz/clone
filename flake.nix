{
  description = "Clone (Aquax) — macOS desktop environment for Linux";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Image builder (qcow-efi for UTM, etc.)
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Swift is NOT a nix dependency: Clone binaries are built by swiftly's
  # toolchain in the VM, and Swift has no ABI stability on Linux, so the image
  # bundles that exact runtime (see Makefile install + nix/appliance.nix)
  # rather than a (mismatched) nixpkgs Swift.
  outputs = { self, nixpkgs, nixos-generators }: let
    system = "aarch64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {
    # NixOS dev VM: builds Clone from the /mnt/clone virtiofs mount.
    nixosConfigurations.clone = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./nix/configuration.nix
        ./nix/clone-desktop.nix
      ];
    };

    # Appliance: self-contained, boots straight to Clone (artifacts baked in).
    nixosConfigurations.appliance = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [ ./nix/appliance.nix ];
    };

    # Bootable disk image for UTM (qcow2 + EFI). Build with --impure because the
    # baked artifact tree lives in the gitignored .build/clone-root:
    #   make os-stage && make os-image   (run inside the aarch64-linux VM)
    packages.${system}.image = nixos-generators.nixosGenerate {
      inherit system;
      format = "qcow-efi";
      modules = [ ./nix/appliance.nix ];
    };

    # Dev shell for building Clone inside the VM
    devShells.${system}.default = pkgs.mkShell {
      name = "clone-dev";
      packages = with pkgs; [
        # Swift comes from swiftly (not nix); see flake comment above.
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
