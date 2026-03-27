# Building

## Prerequisites

- **Swift 6.2+** — [swift.org/install](https://swift.org/install)
- **Rust (stable)** — [rustup.rs](https://rustup.rs)
- **System libraries** — SQLite, Vulkan headers (Linux), pkg-config

## Build Commands

```bash
make all              # Full build: engine → bindings → render → SDK → install-sdk → apps → install
make all-release      # Full build in release mode
make engine           # Rust compositor engine (cargo build -p clone-engine)
make render           # Rust app renderer (cargo build -p clone-render)
make text             # Rust text measurement crate (cargo build -p clone-text)
make audio            # Rust audio engine (cargo build -p clone-audio)
make bindings         # Generate UniFFI Swift bindings (engine + clone-render)
make render-bindings  # Generate UniFFI Swift bindings (clone-render standalone)
make text-bindings    # Generate UniFFI Swift bindings (text)
make audio-bindings   # Generate UniFFI Swift bindings (audio)
make swift            # Compositor + all daemons
make sdk              # swift build + assemble .framework bundles
make install-sdk      # Install frameworks + Rust dylibs to CLONE_ROOT (~/.clone)
make apps             # Build all apps against installed SDK frameworks
make install          # Full install: install-sdk + app bundles + system binaries
make test             # Run all tests (Rust + Swift)
make test-rust        # cargo test --lib
make test-swift       # swift test
```

All build commands accept `CONFIG=release` for optimized builds (e.g. `make sdk CONFIG=release`).

## Build Pipeline

```
make all:
  engine → bindings → render-bindings → text-bindings → audio-bindings
  → swift → sdk → install-sdk → apps → install
```

1. **Rust crates** — `clone-engine`, `clone-render`, `clone-text`, `clone-audio` compiled via Cargo
2. **UniFFI bindings** — generated from each dylib into `Sources/Internal/` and `Sources/FFI/`
3. **Swift build** — compositor + daemons via SPM
4. **SDK assembly** — `build-sdk.sh` links `.o` files into `.framework` bundles at `.build/sdk/`
5. **Install SDK** — copies frameworks + Rust dylibs to `CLONE_ROOT` (`~/.clone/System/Library/`)
6. **App build** — `ycodebuild --prebuilt` compiles each app against the installed frameworks
7. **Full install** — copies app bundles + system binaries to `CLONE_ROOT`

After a SwiftUI change: `make sdk install-sdk` recompiles the SDK, then `make apps` re-links each app against fresh frameworks.

### CLONE_ROOT

`CLONE_ROOT` defaults to `~/.clone`. All installed artifacts live here:

```
~/.clone/
  System/
    CloneDesktop              ← compositor binary
    cloned, keychaind, ...    ← daemon binaries
    Library/
      Frameworks/             ← SDK .framework bundles
        SwiftUI.framework/
        QuartzCore.framework/
        CoreText.framework/
        ...
      libclone_engine.dylib   ← Rust libraries
      libclone_render.dylib
      libclone_text.dylib
  Applications/
    Finder.app/
    Preview.app/
    FontBook.app/
    ...
  Library/
    Fonts/                    ← bundled fonts (Inter, Iosevka)
    LaunchServices/           ← app registry
```

Apps built by `ycodebuild --prebuilt` link against `CLONE_ROOT/System/Library/Frameworks/`. External apps (e.g. Leela, Tunes) use the same path.

## Docker (Linux)

```bash
make docker-build   # Build the container image (swift:6.2-noble + Rust)
make docker-sdk     # Build SDK for Linux inside the container
make docker-apps    # Build all apps for Linux
```

See [Frameworks](frameworks.md) for details on the framework bundle structure.
