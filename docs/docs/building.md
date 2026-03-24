# Building

## Prerequisites

- **Swift 6.2+** — [swift.org/install](https://swift.org/install)
- **Rust (stable)** — [rustup.rs](https://rustup.rs)
- **System libraries** — SQLite, Vulkan headers (Linux), pkg-config

## Build Commands

```bash
make all              # Full build: engine → bindings → compositor → SDK → apps
make engine           # Rust GPU engine only (cargo build -p clone-engine)
make engine-release   # Rust GPU engine (release mode)
make audio            # Rust audio engine (cargo build -p clone-audio)
make bindings         # Generate UniFFI Swift bindings (engine)
make audio-bindings   # Generate UniFFI Swift bindings (audio)
make swift            # Compositor + daemons only (CloneDesktop, keychaind, cloned)
make sdk              # Full swift build + assemble .framework bundles (debug)
make sdk-release      # Assemble .framework bundles (release)
make apps             # Build all apps against prebuilt SDK frameworks
make test             # Run all tests (Rust + Swift)
make test-rust        # cargo test --lib
make test-swift       # swift test
```

## Build Pipeline

The build is split into two stages so that changing SDK sources (e.g. SwiftUI) does not recompile apps:

1. **`make engine`** — Compiles the Rust wgpu renderer (`libclone_engine.dylib`/`.so`)
2. **`make bindings`** — UniFFI generates Swift bindings from the engine dylib into `Sources/Internal/EngineBridge/`
3. **`make audio`** — Compiles the Rust audio engine (`libclone_audio.dylib`/`.so`)
4. **`make audio-bindings`** — UniFFI generates Swift bindings into `Sources/Internal/AudioBridge/`
5. **`make swift`** — Builds the compositor and daemons via SPM (`swift build --product CloneDesktop`)
6. **`make sdk`** — Full `swift build` of all modules, then `build-sdk.sh` assembles `.framework` bundles
7. **`make apps`** — Builds each app with `ycodebuild --prebuilt`, linking against the prebuilt frameworks

After a SwiftUI change, `make sdk` recompiles the SDK, then `make apps` re-links each app in ~0.1s (no recompilation).

## Docker (Linux)

```bash
make docker-build   # Build the container image (swift:6.2-noble + Rust)
make docker-sdk     # Build SDK for Linux inside the container
make docker-apps    # Build all apps for Linux
```

The Docker image is based on `swift:6.2-noble` (Ubuntu 24.04) with Rust and all system dependencies pre-installed. Source is bind-mounted, so output lands in `.build/` on the host.

## SDK Output

After `make sdk`, frameworks are assembled in:

```
.build/sdk/System/Library/Frameworks/
  SwiftUI.framework/
  AppKit.framework/
  Charts.framework/
  ...
```

See [Frameworks](frameworks.md) for details on the framework bundle structure.
