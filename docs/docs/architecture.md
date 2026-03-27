# Architecture

Clone splits across two languages: **Swift** for UI logic and **Rust** for GPU rendering. Each app renders its own pixels via a headless wgpu device and shares the GPU texture with the compositor through IOSurface (macOS) for zero-copy compositing.

## Two-Language Split

| Layer | Language | Responsibility |
|-------|----------|----------------|
| UI framework | Swift | View structs, layout engine, ViewBuilder DSL, App protocol |
| Window manager | Swift | Window chrome, hit testing, focus, drag |
| IPC | Swift | Length-prefixed JSON over Unix sockets + Mach port transfer |
| App renderer | Rust | Per-app headless wgpu rendering via `clone-render` crate |
| Compositor | Rust | Surface compositing, winit event loop, window shadows |
| Texture sharing | Rust | IOSurface ↔ wgpu via `wgpu-iosurface` crate (macOS) |
| Text measurement | Rust | cosmic-text shaping, word wrapping, cursor positioning |
| Audio engine | Rust | CPAL audio playback, exposed via UniFFI (AudioBridge) |

**UniFFI 0.31** bridges Rust and Swift:

- **Engine bridge** — `DesktopDelegate` callback trait (Rust) implemented in Swift. The compositor calls Swift for surface frame assembly; Swift calls Rust to start the engine.
- **Render bridge** — `AppRenderer` object exposed via UniFFI. Apps call `render()` to draw into IOSurface-backed textures. `decode_image()` decodes JPEG/PNG to RGBA.
- **Text bridge** — `measure_text`, `cursor_position`, `list_font_families` exposed via UniFFI.
- **Audio bridge** — `AudioPlayer` and `AudioPlayerDelegate` exposed via UniFFI.

## Source Layout

```
Sources/
  SDK/          SwiftUI, AppKit, QuartzCore, CoreText, SwiftData, Charts,
                MediaPlayer, AVKit, AVFoundation, UniformTypeIdentifiers,
                KeychainServices
  Internal/     CloneProtocol, CloneClient, CloneServer, CloneText, CloneRender,
                SharedSurface, PosixShim, CPosixShim, EngineBridge,
                AudioBridge, SwiftDataMacros
  FFI/          CText, CAudio, CEngine, CRender, CPosixShim, CSQLite
  Apps/         Compositor, Finder, Settings, Dock, MenuBar, Password,
                TextEdit, Preview, LoginWindow, FontBook
  Daemons/      cloned, CloneDaemon, keychaind, CloneKeychain,
                launchservicesd, CloneLaunchServices,
                avocadoeventsd, AvocadoEvents
  Tools/        ycodebuild, open
```

## Module Map

```
┌─────────────────────────────────────────────────────────────┐
│  Apps (Finder, Settings, Dock, MenuBar, Preview, FontBook)  │
│  import SwiftUI  ← same API as Apple's                      │
├──────────────────────────┬──────────────────────────────────┤
│  SDK/SwiftUI             │  SDK/AppKit (NSColor, NSImage)   │
│  SDK/QuartzCore          │  SDK/CoreText (CTFont, CTLine)   │
│  SDK/SwiftData           │  SDK/AVFoundation (AVPlayer)     │
│  SDK/Charts              │  SDK/MediaPlayer, KeychainServices│
├──────────────────────────┴──────────────────────────────────┤
│  Internal/CloneClient  — app-side IPC + Mach port transfer  │
│  Internal/CloneRender  — headless GPU rendering (UniFFI)    │
│  Internal/SharedSurface — double-buffered mmap (legacy)     │
├─────────────────────────────────────────────────────────────┤
│  Internal/EngineBridge  — compositor-side UniFFI bridge     │
│  Internal/CloneServer   — compositor-side IPC server        │
├─────────────────────────────────────────────────────────────┤
│  Rust: clone-render     │  Rust: wgpu-iosurface            │
│  DesktopRenderer, all   │  IOSurface-backed wgpu textures  │
│  GPU pipelines, shaders │  Mach port cross-process sharing │
├─────────────────────────┼──────────────────────────────────┤
│  Rust: clone-engine     │  Rust: clone-text                │
│  winit, compositor,     │  cosmic-text measurement,        │
│  surface blending       │  font enumeration                │
├─────────────────────────┼──────────────────────────────────┤
│  Rust: clone-audio      │                                  │
│  CPAL, symphonia        │                                  │
└─────────────────────────┴──────────────────────────────────┘
```

## Rendering Pipeline

Apps drive their own rendering via `CADisplayLink`. No more compositor-driven `requestFrame` round-trips.

```
@main App.body → WindowGroup { views }
→ View structs with modifier chaining
→ ViewBuilder → _resolve() → ViewNode tree
→ Layout.measure/layout → LayoutNode tree
→ CommandFlattener.flatten → FlatRenderCommand[]
→ Convert to RenderCommand[] (clone-render types)
→ HeadlessDevice.render() into IOSurface-backed wgpu texture
→ IOSurface shared with compositor via Mach port (zero-copy)
→ Compositor: SurfaceCompositor composites all window textures → screen
```

The compositor renders only window chrome (title bar, traffic lights, shadows). App content comes directly from the shared IOSurface — no deserialization, no re-rendering.

## Image Pipeline

Raster images (JPEG, PNG, GIF, BMP, WebP) are decoded via the `image` crate through a `decode_image()` UniFFI function. Decoded RGBA pixels are uploaded to the GPU as textures via `RegisterTexture`. The `ImagePipeline` in `clone-render` renders them as textured quads with bilinear filtering. Textures are registered once and cached by ID — subsequent frames only emit the draw command.

## Hit Testing

Hit test results are three-state: `.tap(id, frame)` (actionable), `.absorbed` (opaque view consumed the event), or `nil` (miss — pass through). Opaque views (rect, roundedRect, image, toggle, slider, picker, textField) absorb events to prevent leak-through to windows behind. When a child returns `.absorbed`, ancestor `.onTap` handlers still fire.

## Lazy List

Data-driven `List(data) { row }` defers row closure evaluation. The `LazyRowRegistry` stores the data + closure; the layout engine only evaluates closures for visible rows (plus a 2-row buffer). Off-screen rows are evicted from the cache. The virtual list layout uses uniform row height estimated from the first row, reducing layout work from O(n) to O(visible).

## Daemons

| Daemon | Library | Purpose |
|--------|---------|---------|
| `cloned` | `CloneDaemon` | Now-playing info aggregation, media key routing |
| `keychaind` | `CloneKeychain` | SQLite-backed keychain storage, SecItem API |
| `launchservicesd` | `CloneLaunchServices` | App launching, bundle resolution, `/Applications/` scanning |
| `avocadoeventsd` | `AvocadoEvents` | Inter-process event routing (typed pub/sub over Unix sockets) |

## Text Measurement

Text measurement uses cosmic-text (Rust) via UniFFI. The `clone-text` crate provides `measure_text`, `cursor_position`, and `list_font_families`. Results are cached on both sides. The layout engine calls `TextMeasurer.measure()` during the measure pass.

## IPC Protocol

4-byte big-endian length-prefixed JSON over Unix socket (`/tmp/clone-compositor.sock`). Messages are batched per socket read and dispatched asynchronously to the main queue, preventing the display link from being starved. IOSurface Mach ports travel via a separate bootstrap-server-based Mach channel. See [IPC Protocol](ipc.md) for message reference.

## Process Model

Each app runs as a separate process with its own wgpu device. The compositor manages windows and routes input. LoginWindow gates the session.

```
CloneDesktop (compositor)
  ├── cloned (now-playing daemon)
  ├── keychaind (keychain daemon)
  ├── launchservicesd (app launching daemon)
  ├── avocadoeventsd (event routing daemon)
  ├── LoginWindow (pre-session)
  │     └── on login success → starts:
  ├── Dock
  ├── MenuBar
  ├── Finder
  ├── Settings
  ├── TextEdit
  ├── Preview
  ├── FontBook
  └── Password
```
