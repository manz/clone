# Architecture

Clone splits across two languages: **Swift** for UI logic and **Rust** for GPU rendering.

## Two-Language Split

| Layer | Language | Responsibility |
|-------|----------|----------------|
| UI framework | Swift | View structs, layout engine, ViewBuilder DSL, App protocol |
| Window manager | Swift | Window chrome, hit testing, focus, drag |
| IPC | Swift | Length-prefixed JSON over Unix sockets |
| GPU renderer | Rust | wgpu instanced draws, surface compositor, winit event loop |
| Audio engine | Rust | CPAL audio playback, exposed via UniFFI (AudioBridge) |

**UniFFI 0.28** bridges Rust and Swift in two places:

- **Engine bridge** — `DesktopDelegate` callback trait (Rust) implemented in Swift (`SwiftDesktopDelegate`). Rust calls Swift for render commands; Swift calls Rust to start the engine.
- **Audio bridge** — `AudioPlayer` and `AudioPlayerDelegate` exposed via UniFFI. Swift's `AVFoundation` module wraps these as `AVPlayer`/`AVQueuePlayer`.

## Source Layout

```
Sources/
  SDK/          SwiftUI, AppKit, SwiftData, Charts, MediaPlayer, AVKit,
                AVFoundation, UniformTypeIdentifiers, KeychainServices
  Internal/     CloneProtocol, CloneClient, CloneServer, CloneText,
                PosixShim, EngineBridge, AudioBridge, SwiftDataMacros
  FFI/          CText, CAudio, CEngine, CSQLite
  Apps/         Compositor, Finder, Settings, Dock, MenuBar,
                Password, TextEdit, Preview, LoginWindow
  Daemons/      cloned, CloneDaemon, keychaind, CloneKeychain
  Tools/        ycodebuild
```

## Module Map

```
┌─────────────────────────────────────────────────────────┐
│  Apps/                                                  │
│  Finder, Settings, Dock, MenuBar, TextEdit, Preview,    │
│  Password, LoginWindow                                  │
│  import SwiftUI  ← same API as Apple's                  │
├─────────────────────────────────────────────────────────┤
│  SDK/SwiftUI     │  SDK/AppKit (NSColor, NSImage shims) │
│  SDK/Charts      │  SDK/AVFoundation (AVPlayer, AVQueue)│
│  SDK/SwiftData   │  SDK/MediaPlayer (MPNowPlayingInfo)  │
│  (SQLite via     │  SDK/KeychainServices (SecItem API)  │
│   FFI/CSQLite)   │  SDK/UniformTypeIdentifiers (UTType) │
├─────────────────────────────────────────────────────────┤
│  Internal/CloneClient / Internal/CloneProtocol — IPC    │
├─────────────────────────────────────────────────────────┤
│  Internal/EngineBridge    │  Internal/AudioBridge       │
│  (UniFFI)                 │  (UniFFI)                   │
├─────────────────────────────────────────────────────────┤
│  FFI/CEngine, CText, CAudio, CSQLite                    │
├─────────────────────────────────────────────────────────┤
│  Rust: clone-engine       │  Rust: clone-audio          │
│  wgpu, surface compositor │  CPAL, symphonia decoder    │
│  winit event loop         │                             │
└─────────────────────────────────────────────────────────┘
```

### Daemons

| Daemon | Library | Path | Purpose |
|--------|---------|------|---------|
| `cloned` | `CloneDaemon` | `Sources/Daemons/` | Now-playing info aggregation, media key routing |
| `keychaind` | `CloneKeychain` | `Sources/Daemons/` | SQLite-backed keychain storage, SecItem API |

## Rendering Pipeline

```
@main App.body → WindowGroup { views }
→ View structs with modifier chaining
→ ViewBuilder collects → _resolve() each View to ViewNode
→ ViewNode tree → Layout.measure/layout → LayoutNode tree
→ CommandFlattener.flatten → FlatRenderCommand[] (CGFloat)
→ toIPC() converts CGFloat→Float → IPCRenderCommand over socket
→ Bridge.toEngineCommands → RenderCommand[] (Float/f32)
→ Rust batches by type → instanced wgpu draws
→ Each window → offscreen texture → SurfaceCompositor blends onto screen
```

## IPC Protocol

4-byte **big-endian** length-prefixed JSON over Unix socket (`/tmp/clone-compositor.sock`). See [IPC Protocol](ipc.md) for full message reference.

## Process Model

Each app runs as a separate process. The compositor manages windows and routes input. LoginWindow gates the session — daemons start immediately, standard apps only after login.

```
CloneDesktop (compositor)
  ├── cloned (now-playing daemon)
  ├── keychaind (keychain daemon)
  ├── LoginWindow (pre-session)
  │     └── on login success → starts:
  ├── Dock
  ├── MenuBar
  ├── Finder
  ├── Settings
  ├── TextEdit
  ├── Preview
  └── Password
```
