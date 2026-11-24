# Clone appliance + dev VM (mkosi / Debian)

The Clone appliance is a **Debian 13 (trixie)** image built with [mkosi](https://github.com/systemd/mkosi).
It boots straight to the Clone desktop on a plain FHS system - no nix. The same VM
also self-hosts the build (Swift via swiftly, Rust via rustup), so one OS covers both
the appliance and dev, and the in-VM glibc matches the image (no cross-distro mismatch).

This replaced the earlier NixOS appliance + Ubuntu/Lima builder. See git history for
`nix/appliance.nix`, `nix/dev-overlay.nix`, and `flake.nix` if you need the old path.

## Build the appliance image

Run on Linux (in the dev VM) with mkosi 27+ installed:

```bash
make os-stage      # assemble .build/clone-root: binaries + bundled Swift runtime + wallpapers
make mkosi-image   # stage + run mkosi (config in mkosi/) -> bootable disk image
```

`mkosi.conf` pulls `.build/clone-root` into the image via `ExtraTrees=../.build/clone-root:/`.
The runtime layout (`/System`, `/Applications`, `/Library`, users/groups, systemd units,
tmpfiles, ldconfig) is materialized by `mkosi.extra/` plus `mkosi.finalize`.

## What's in the image

- **Users**: `_windowserver` (compositor, system), `manz` (desktop), `dev` (admin/SSH).
  `manz` has linger on, so `user@<uid>.service` runs at boot and owns the session daemons.
- **Login**: `clone-loginwindow.service` (root) is the login gate; on auth it starts
  `clone-session.target` in the user's manager (Dock, Finder, MenuBar + the daemons).
- **Sockets**: `/run/clone` (tmpfiles-owned `2775 _windowserver clone`) holds the
  cross-user sockets. It is NOT a systemd `RuntimeDirectory`, so a compositor restart
  does not wipe it and take the session daemons down with it.
- **Graphics/runtime**: native Debian mesa/vulkan/libdrm/libinput + the bundled Swift
  runtime under `/System/Library/swift-linux`, resolved via `ld.so.conf.d` + ldconfig.

## Self-host dev loop

One VM builds and runs Clone with the repo mounted at `/Clone` (virtiofs). Edit on the
Mac (or over SSH with `claude`), build in-VM, restart one service:

| Changed | Build (cwd `/Clone`) | Restart |
|---|---|---|
| one app's Swift | `ycodebuild --prebuilt ... --target <App>` + install | `systemctl --user -M manz@ restart <app>` |
| SDK module | `make sdk && make install-sdk` | affected apps, or `sudo systemctl restart clone-windowserver` |
| compositor | `make swift && make install` | `sudo systemctl restart clone-windowserver` |
| daemon | `make swift && make install` | `systemctl --user -M manz@ restart <daemon>` |
| Rust engine | `make bindings && make sdk && make install` | `sudo systemctl restart clone-windowserver` (loads `/Clone/target/debug` via RUNPATH) |
| libghostty-vt | `make ghostty` (zig 0.17), then `make sdk && make install` | restart Terminal/Console |

A compositor restart bounces to LoginWindow but the session survives (apps reconnect,
daemons persist under the lingered user manager).
