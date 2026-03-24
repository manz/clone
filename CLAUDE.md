# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Clone (codename **Aquax**) is a macOS desktop environment targeting Linux — a from-scratch compositor, window manager, and UI framework. Swift handles UI logic (layout, DSL, window chrome, app lifecycle) and Rust handles GPU rendering (wgpu/Metal). Apps run as separate processes communicating with the compositor over Unix domain sockets.

**The SDK surface must be 100% the same interface as Apple's counterparts.** App code must compile against both Clone's SwiftUI/AppKit and Apple's real SwiftUI/AppKit with only `#if canImport(CloneClient)` guards for Clone-specific lifecycle.

## Build & Test Commands

```bash
make all          # Full build: engine → bindings → compositor → SDK → apps
make engine       # Rust engine only (cargo build)
make bindings     # Generate UniFFI Swift bindings from libclone_engine.dylib
make swift        # Compositor + daemons only (CloneDesktop, keychaind, cloned)
make sdk          # Full swift build + assemble .framework bundles
make apps         # Build all app targets against prebuilt SDK frameworks
make test         # Run all tests (Rust + Swift)
make test-rust    # cargo test --lib
make test-swift   # swift test
```

Run the compositor: `swift run CloneDesktop` (after `make all`)

### Build pipeline

The build is split into two stages to avoid recompiling apps when SDK sources change:

1. **`make sdk`** — compiles all Swift modules via `swift build`, then `scripts/build-sdk.sh` assembles `.framework` bundles (dylib + swiftmodule) at `.build/sdk/System/Library/Frameworks/`.
2. **`make apps`** — builds each app with `ycodebuild --prebuilt`, which generates a standalone SPM package that links against the prebuilt frameworks via `-F` flags. Apps only compile their own source — no SDK recompilation.

After a SwiftUI change: `make sdk` recompiles the SDK (~30s), then `make apps` re-links each app in ~0.1s.

### Building apps with ycodebuild

`ycodebuild` generates an SPM package that compiles app source against Clone's SDK instead of Apple's frameworks.

```bash
# Prebuilt mode (fast — links against .framework bundles from make sdk)
swift run ycodebuild --prebuilt --source-dir ~/Projects/Tunes/Tunes/Tunes --target Tunes

# Source mode (slow — recompiles Clone from source, no make sdk needed)
swift run ycodebuild --source-dir ~/Projects/Tunes/Tunes/Tunes --target Tunes

# Internal apps use --output-dir to avoid clobbering Clone's Package.swift
swift run ycodebuild --prebuilt --output-dir .build/apps/Finder --source-dir Sources/FinderApp --target Finder
```

**How `--prebuilt` works:** The generated Package.swift uses `-F` (framework search path) in `swiftSettings` so `import SwiftUI` resolves to Clone's `SwiftUI.framework` before Apple's. It also passes `-I` for internal Swift modules (PosixShim, CloneText, etc.), `-Xcc -fmodule-map-file` for C FFI modules (clone_textFFI, etc.), and `-load-plugin-executable` for SwiftDataMacros.

**Mode switching:** ycodebuild tracks the last build mode in `.aquax/.build-mode`. Switching between `--prebuilt` and source mode automatically cleans the build cache to avoid stale `.swiftmodule` files that would make `#if canImport` return wrong results.

The app binary connects to the compositor over `/tmp/clone-compositor.sock`.

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
│  View structs (Text,   │  NSColor, NSAppearance         │
│  VStack, Button, etc.) │  Semantic system colors        │
│  ViewBuilder, ForEach,  │                                │
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
@main App.body → WindowGroup { views }
→ View structs (Text, VStack, Button, etc.) with modifier chaining
→ ViewBuilder collects via buildExpression → _resolve() each View to ViewNode
→ ViewNode tree → Layout.measure/layout → LayoutNode tree
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
| `Sources/SwiftUI/` | UI framework: View structs, ViewNode IR, Layout, Font, Color, App protocol |
| `Sources/SwiftUI/Views/` | View structs: Text, VStack, HStack, ZStack, Button, Rectangle, etc. |
| `Sources/AppKit/` | NSColor, NSAppearance shims for Linux |
| `Sources/SwiftData/` | SQLite-backed persistence (PersistentModel, ModelContainer) |
| `Sources/CloneProtocol/` | IPC message types (Codable, uses Float wire format) |
| `Sources/CloneClient/` | App-side Unix socket client |
| `Sources/CloneServer/` | Compositor-side GCD socket server |
| `Sources/EngineBridge/` | FlatRenderCommand↔RenderCommand, CGFloat↔Float boundary |
| `engine/src/` | Rust wgpu renderer, surface compositor, winit event loop |

### App targets (separate processes)

`CloneDesktop` (compositor), `Finder`, `Settings`, `Dock`, `MenuBar`, `PasswordApp`, `TextEditApp`, `PreviewApp`, `LoginWindow` — each uses `@main` + `App` protocol. The compositor and daemons (`keychaind`, `cloned`) are built directly via SPM. All other apps are built by `ycodebuild --prebuilt` against the SDK frameworks, with binaries at `.build/apps/<name>/.build/`.

## Code Style — STRICT RULES

### Apple API fidelity
- **App code must compile against real Apple SwiftUI.** Test by pasting into an Xcode project.
- **All DSL types are structs, not free functions.** `Text("hi")` creates a `Text` struct, `VStack { }` creates a `VStack` struct — same syntax as Apple's SwiftUI.
- **Use only standard SwiftUI/AppKit types in app code.** `Color`, `Font`, `Text`, `VStack`, `HStack`, `ZStack`, `ForEach`, `Spacer`, `Rectangle`, `RoundedRectangle`, `.font(.system(size:weight:))`, `.foregroundColor()`, `.bold()`, `.frame()`, `.padding()`, etc.
- **Use `CGFloat` everywhere** — never `Float` in public API. Bridge converts to Float at the engine boundary.
- **Use `Color(red:green:blue:opacity:)` for inline colors** — not `Color(r:g:b:a:)` or `Color(nsColor:)` in app code (those are Clone-internal).
- **Use `ForEach` not `for...in` in ViewBuilder closures** — Apple's ViewBuilder doesn't support `for...in`.
- **`#if canImport(CloneClient)` guards** for Clone-specific APIs: `WindowState`, `WindowConfiguration`, `SystemActions`, event handlers.

### View structs and ViewNode
- **All DSL elements are proper structs conforming to `View`** — `Text`, `VStack`, `HStack`, `ZStack`, `Rectangle`, `RoundedRectangle`, `Button`, `Spacer`, `Image`, `Divider`, `ScrollView`, `List`, `Toggle`, `Slider`, `Picker`, `TextField`, `Menu`, `Label`, `Section`, `NavigationStack`, `NavigationSplitView`, `GeometryReader`, `ForEach`.
- **Text-specific modifiers return `Text`** — `.font()`, `.bold()`, `.italic()`, `.foregroundColor()`, `.fontWeight()` on `Text` return `Text` for type-safe chaining. Generic modifiers (`.frame()`, `.padding()`, etc.) are on `View` extension and return `ViewNode`.
- **`ViewNode` is the internal IR** — produced by `View.body` and consumed by Layout, Reconciler, CommandFlattener. Apps should never reference `ViewNode` directly.
- **`_resolve()` materializes any View to ViewNode** — walks the `body` chain to terminal `ViewNode`. Used internally by `ViewBuilder` and modifier extensions. Framework code that needs a `ViewNode` from a View struct should call `_resolve()` or `.body`.
- **Never reference `ViewNode` in app code.** Use View structs and `some View` return types.

### Colors
- **Standard SwiftUI colors in apps:** `.primary`, `.secondary`, `.gray`, `.blue`, `.red`, etc.
- **Inline `Color(red:green:blue:opacity:)` for custom colors** — no `Color.adaptive()`, no `Color(nsColor:)` in app code.
- **`WindowChrome.*` is compositor-internal only** — never in app code.
- **`NSColor` is for framework internals** (WindowChrome delegates to NSColor). Apps use standard Color.

### Font
- `.font(.system(size: 13, weight: .semibold))` — not `.fontSize()` (deprecated).
- `.bold()` and `.fontWeight(.semibold)` are valid SwiftUI modifiers.
- `Font` has preset styles: `.headline`, `.body`, `.caption`, `.title`, etc.

## State Management — StateGraph

`StateGraph` provides persistent state storage across frame rebuilds (`Sources/SwiftUI/StateGraph.swift`).

**Key format:** `scope/file:line:callIndex`
- **Scope** — pushed by `ForEach` with each item's `Identifiable.id`. Nested ForEach produces nested scopes: `album-7/track-42/TrackRow.swift:8:0`. This matches Apple's structural identity: state is stable across reorders, insertions, deletions.
- **Source location** — `#fileID:#line` from the `@State`/`@StateObject` declaration site.
- **Call index** — disambiguates multiple `@State` at the same file:line outside ForEach (increments per call, resets each frame via `resetCounter()`).

**Frame lifecycle:** `resetCounter()` is called at the start of each frame rebuild (in `App.swift`). This resets call indices and scope stack so the same call sequence maps back to the same slots.

**ForEach pushes scope:** Every ForEach variant (Identifiable, explicit `id:`, Range, `\.self`) calls `pushScope("\(item.id)")` before the content closure and `popScope()` after. This is why Apple requires `id:` or `Identifiable` — it's not just for diffing, it's for state storage identity.

## Known Gotchas

- **wgpu buffer overwrites**: Solid and rounded rect pipelines use SEPARATE instance buffers to avoid `queue.write_buffer` overwrites within the same command encoder.
- **DPI**: Swift uses logical pixels (CGFloat), Rust multiplies by `scale_factor()`. Shadow blur/radius are NOT DPI-scaled.
- **F12**: Debug key that dumps all surfaces and commands to `/tmp/clone-frame-dump.txt`.
- **Layout engine limitation**: `nil`-sized rects in ZStack (e.g. from `.background()`) expand to full constraint, eating all space in parent VStack/HStack. Use explicit-sized rects instead.
- **HStack layout**: Children are measured with remaining width (not full width) to prevent overflow. Mirrors VStack's remaining-height approach.
- **ScrollView**: Fills proposed size, lays out content with unbounded constraint in scroll axis, wraps in `.clipped` node. Actual scroll offset not yet implemented.
- **Hit testing**: `hitTestTap()` walks ancestors to find `.onTap` — the old `hitTest()` returned deepest leaf which was never `.onTap`.
- **Rust edition 2024**, wgpu 28, UniFFI 0.28 proc-macro, cosmic-text 0.12.
- `[profile.dev.package."*"] opt-level = 2` — dependencies compiled with optimizations in debug.

## Roadmap

See `RENDER.md` for the compositor architecture evolution plan (per-window textures → compositor pass → dirty tracking → glassmorphism → multi-process).
