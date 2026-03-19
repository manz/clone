# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Clone (codename **Aquax**) is a macOS desktop environment targeting Linux — a from-scratch compositor, window manager, and UI framework. Swift handles UI logic (layout, DSL, window chrome, app lifecycle) and Rust handles GPU rendering (wgpu/Metal). Apps run as separate processes communicating with the compositor over Unix domain sockets.

**The SDK surface must be 100% the same interface as Apple's counterparts.** App code must compile against both Clone's SwiftUI/AppKit and Apple's real SwiftUI/AppKit with only `#if canImport(CloneClient)` guards for Clone-specific lifecycle.

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

### Module stack

```
┌─────────────────────────────────────────────────────────┐
│  Apps (Finder, Settings, Dock, MenuBar)                 │
│  import SwiftUI  ← same API as Apple's                  │
├─────────────────────────────────────────────────────────┤
│  SwiftUI module        │  AppKit module (NSColor shim)  │
│  Color, Font, View,    │  NSColor, NSAppearance         │
│  ViewBuilder, ForEach,  │  Semantic system colors        │
│  @main App protocol    │                                │
├─────────────────────────────────────────────────────────┤
│  SwiftData module      │  CloneClient / CloneProtocol   │
│  SQLite persistence    │  IPC over Unix sockets         │
├─────────────────────────────────────────────────────────┤
│  EngineBridge (UniFFI) — CGFloat→Float at boundary      │
├─────────────────────────────────────────────────────────┤
│  Rust engine: wgpu renderer, surface compositor, winit  │
└─────────────────────────────────────────────────────────┘
```

### Rendering pipeline

```
@main App.body → WindowGroup { views } → ViewNode tree
→ Layout.measure/layout → LayoutNode tree
→ CommandFlattener.flatten → FlatRenderCommand[] (CGFloat)
→ toIPC() converts CGFloat→Float → IPCRenderCommand over socket
→ Bridge.toEngineCommands → RenderCommand[] (Float/f32)
→ Rust batches by type (rects, shadows, text) → instanced wgpu draws
→ Each window renders to offscreen texture → SurfaceCompositor blends onto screen
```

### IPC protocol (CloneProtocol)

Length-prefixed JSON over Unix socket (`/tmp/clone-compositor.sock`). Two message types:
- `AppMessage` (app → compositor): register, frame, setTitle, close, launchApp, restoreApp
- `CompositorMessage` (compositor → app): windowCreated, requestFrame, resize, pointer/key events

### Key modules

| Module | Purpose |
|--------|---------|
| `Sources/SwiftUI/` | UI framework: View, ViewNode, Layout, Font, Color, App protocol |
| `Sources/AppKit/` | NSColor, NSAppearance shims for Linux |
| `Sources/SwiftData/` | SQLite-backed persistence (PersistentModel, ModelContainer) |
| `Sources/CloneProtocol/` | IPC message types (Codable, uses Float wire format) |
| `Sources/CloneClient/` | App-side Unix socket client |
| `Sources/CloneServer/` | Compositor-side GCD socket server |
| `Sources/EngineBridge/` | FlatRenderCommand↔RenderCommand, CGFloat↔Float boundary |
| `engine/src/` | Rust wgpu renderer, surface compositor, winit event loop |

### App targets (separate processes)

`CloneDesktop` (compositor), `Finder`, `Settings`, `Dock`, `MenuBar` — each uses `@main` + `App` protocol.

## Code Style — STRICT RULES

### Apple API fidelity
- **App code must compile against real Apple SwiftUI.** Test by pasting into an Xcode project.
- **Use only standard SwiftUI/AppKit types in app code.** `Color`, `Font`, `Text`, `VStack`, `HStack`, `ZStack`, `ForEach`, `Spacer`, `Rectangle`, `RoundedRectangle`, `.font(.system(size:weight:))`, `.foregroundColor()`, `.bold()`, `.frame()`, `.padding()`, etc.
- **Use `CGFloat` everywhere** — never `Float` in public API. Bridge converts to Float at the engine boundary.
- **Use `Color(red:green:blue:opacity:)` for inline colors** — not `Color(r:g:b:a:)` or `Color(nsColor:)` in app code (those are Clone-internal).
- **Use `ForEach` not `for...in` in ViewBuilder closures** — Apple's ViewBuilder doesn't support `for...in`.
- **`#if canImport(CloneClient)` guards** for Clone-specific APIs: `WindowState`, `WindowConfiguration`, `SystemActions`, event handlers.

### ViewNode is internal
- **Never reference `ViewNode` in app code.** Use DSL functions and `some View` return types.
- `ViewNode` is the internal IR — apps should never see it, type it, or import it.

### Colors
- **Standard SwiftUI colors in apps:** `.primary`, `.secondary`, `.gray`, `.blue`, `.red`, etc.
- **Inline `Color(red:green:blue:opacity:)` for custom colors** — no `Color.adaptive()`, no `Color(nsColor:)` in app code.
- **`WindowChrome.*` is compositor-internal only** — never in app code.
- **`NSColor` is for framework internals** (WindowChrome delegates to NSColor). Apps use standard Color.

### Font
- `.font(.system(size: 13, weight: .semibold))` — not `.fontSize()` (deprecated).
- `.bold()` and `.fontWeight(.semibold)` are valid SwiftUI modifiers.
- `Font` has preset styles: `.headline`, `.body`, `.caption`, `.title`, etc.

## Known Gotchas

- **wgpu buffer overwrites**: Solid and rounded rect pipelines use SEPARATE instance buffers to avoid `queue.write_buffer` overwrites within the same command encoder.
- **DPI**: Swift uses logical pixels (CGFloat), Rust multiplies by `scale_factor()`. Shadow blur/radius are NOT DPI-scaled.
- **F12**: Debug key that dumps all surfaces and commands to `/tmp/clone-frame-dump.txt`.
- **Layout engine limitation**: `nil`-sized rects in ZStack (e.g. from `.background()`) expand to full constraint, eating all space in parent VStack/HStack. Use explicit-sized rects instead.
- **Hit testing**: `hitTestTap()` walks ancestors to find `.onTap` — the old `hitTest()` returned deepest leaf which was never `.onTap`.
- **Rust edition 2024**, wgpu 28, UniFFI 0.28 proc-macro, cosmic-text 0.12.
- `[profile.dev.package."*"] opt-level = 2` — dependencies compiled with optimizations in debug.

## Roadmap

See `RENDER.md` for the compositor architecture evolution plan (per-window textures → compositor pass → dirty tracking → glassmorphism → multi-process).
