# Running

## macOS (Development)

After building, run the compositor:

```bash
swift run CloneDesktop
```

This starts the compositor and launches the standard apps (Dock, MenuBar, Finder) as child processes. Press **F12** to dump a frame debug log to `/tmp/clone-frame-dump.txt`.

## Linux (VM)

The NixOS release image boots directly into Clone. For development with Lima:

```bash
make vm-create    # Create Ubuntu VM
make vm-start     # Boot it
make vm-ssh       # Shell in
# Inside VM:
cd /mnt/clone && make all && make sdk
```

The compositor starts as a systemd user service, rendering directly to the DRM/KMS display via winit + wgpu (Vulkan).
