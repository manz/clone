# NixOS Image

The release target is a NixOS VM image where Clone is the only desktop session.

## Architecture

```
Docker (build)  →  SDK + app binaries  →  NixOS VM (runtime)
swift + cargo      .framework bundles      Mesa/Vulkan, PipeWire
                   .app bundles            boots into CloneDesktop
```

Build and runtime are decoupled. Docker produces the binaries; the NixOS image only contains the runtime (GPU drivers, audio, fonts) and the pre-built Clone artifacts.

## System Layout

The NixOS image replicates the macOS filesystem hierarchy:

- `/Applications/*.app/` — app bundles with `Contents/Linux/` executables
- `/System/Library/Frameworks/*.framework/` — SDK dynamic libraries
- `/Library/` — system-wide preferences and support files
- `/Users/` — home directories

## Configuration

The NixOS system is defined in `flake.nix` with two modules:

- `nix/configuration.nix` — base system: kernel, GPU (virtio-gpu + Mesa), audio (PipeWire), fonts, SSH, user account
- `nix/clone-desktop.nix` — Clone session: systemd service for CloneDesktop, `/Applications` and `/System/Library/Frameworks` directory creation, SDK/app symlinks

## Building the Image

```bash
# Requires Nix with flakes enabled
nix build .#nixosConfigurations.clone.config.system.build.vm
```

This produces a QCOW2 disk image that boots directly into the Clone desktop.

## Development VM (Lima)

For iterative development, use Lima with an Ubuntu base:

```bash
make vm-create    # Create Ubuntu VM with Lima
make vm-start     # Boot
make vm-ssh       # Shell in
```

The Clone source tree is mounted via virtiofs at `/mnt/clone`. Build inside the VM, and the NixOS release image is built separately in CI.
