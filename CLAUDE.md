# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Clone is a macOS desktop environment clone — a from-scratch compositor, window manager, and UI framework. Swift handles UI logic (layout, DSL, window chrome, app lifecycle) and Rust handles GPU rendering (wgpu/Metal). Apps run as separate processes communicating with the compositor over Unix domain sockets.

Note that the SDK surface must be 100% the same interface as it's Apple counterpart.

## Build & Test Commands

```bash
make all          # Full build: cargo build → UniFFI bindings → swift build
make engine       # Rust engine only (cargo build)
make bindings     # Generate UniFFI Swift bindings from libclone_engine.dylib
make swift        # Swift package (libs + compositor)
make apps         # Build all app targets (Finder, Settings, Dock, MenuBar)
make test         # Run all tests (Rust + Swift)
make test-rust    # cargo test --lib
make test-swift   # swift test
```

Run the compositor: `swift run CloneDesktop` (after `make all`)

## Architecture

### Two-language split

- **Rust engine** (`engine/src/`): wgpu GPU rendering, surface compositor, winit event loop
- **Swift** (`Sources/`): UI framework (SwiftUI-like DSL), layout engine, window manager, IPC

**UniFFI 0.28** bridges Rust↔Swift. The `DesktopDelegate` callback trait (Rust) is implemented in Swift (`SwiftDesktopDelegate`). Rust calls Swift to get render commands each frame; Swift calls Rust to start the engine.

### Rendering pipeline

```
Swift App body → ViewNode tree → Layout.measure/layout → LayoutNode tree
→ CommandFlattener.flatten → FlatRenderCommand[] → Bridge.toEngineCommands (UniFFI)
→ Rust DesktopRenderer batches by type (rects, shadows, text) → instanced wgpu draws
→ Each window renders to offscreen texture → SurfaceCompositor blends onto screen
```

### IPC protocol (CloneProtocol)

Length-prefixed JSON over Unix socket (`/tmp/clone-compositor.sock`). Two message types:
- `AppMessage` (app → compositor): register, frame, setTitle, close, launchApp, restoreApp
- `CompositorMessage` (compositor → app): windowCreated, requestFrame, resize, pointer/key events

### Key modules

| Module | Purpose |
|--------|---------|
| `engine/src/window.rs` | Winit event loop, GPU state, render orchestration |
| `engine/src/surface_compositor.rs` | Per-window offscreen textures, compositor pass |
| `engine/src/renderer/mod.rs` | Batch orchestrator (rect, shadow, text pipelines) |
| `engine/src/commands.rs` | `RenderCommand` enum, `SurfaceFrame` |
| `engine/src/ffi.rs` | UniFFI exports: `DesktopDelegate` trait, `DesktopEngine` |
| `Sources/SwiftUI/Layout.swift` | Measure/layout constraint engine |
| `Sources/SwiftUI/CommandFlattener.swift` | ViewNode tree → flat render commands |
| `Sources/SwiftUI/WindowManager.swift` | Window state, z-order, chrome, drag/resize |
| `Sources/CloneProtocol/Messages.swift` | IPC message types (Codable) |
| `Sources/CloneServer/CompositorServer.swift` | GCD-based Unix socket server |
| `Sources/CloneClient/AppClient.swift` | App-side socket client |
| `Sources/EngineBridge/Bridge.swift` | FlatRenderCommand↔RenderCommand conversion |

### App targets (separate processes)

`CloneDesktop` (compositor), `Finder`, `Settings`, `Dock`, `MenuBar` — each connects via `AppClient` and sends render commands over IPC.

## Code Style

- **Use DSL functions, not ViewNode constructors.** App code must use `VStack { }`, `HStack { }`, `ZStack { }`, `Text()`, `Rectangle()`, `Spacer()` etc. — never `ViewNode.vstack(...)`, `ViewNode.zstack(children: [...])`, or `.text(...)` directly. The `ViewNode` enum is an internal implementation detail. App code should read like real SwiftUI.
- **Use standard Color names.** `.blue`, `.red`, `.primary`, `.secondary`, `.gray` — matching Apple's SwiftUI Color API. Clone-specific compositor colors live in `WindowChrome.*`. AppKit semantic colors use `NSColor.*`.
- **No direct CloneClient/CloneProtocol in apps.** Use `WindowState.shared` for window size, `.navigationTitle()` for window title, `SystemActions.shared` for app launch/restore.

## Known Gotchas

- **wgpu buffer overwrites**: Multiple render passes sharing an encoder overwrite `queue.write_buffer` data. Submit per-batch or use offsets.
- **DPI**: Swift uses logical pixels, Rust multiplies by `scale_factor()`. Shadow blur/radius are NOT DPI-scaled.
- **F12**: Debug key that dumps all surfaces and commands to `/tmp/clone-frame-dump.txt`.
- **Rust edition 2024**, wgpu 28, UniFFI 0.28 proc-macro, cosmic-text 0.12.
- `[profile.dev.package."*"] opt-level = 2` — dependencies compiled with optimizations in debug.

## Roadmap

See `RENDER.md` for the compositor architecture evolution plan (per-window textures → compositor pass → dirty tracking → glassmorphism → multi-process).
