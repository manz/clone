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

## Module Map

```
┌─────────────────────────────────────────────────────────┐
│  Apps                                                   │
│  Finder, Settings, Dock, MenuBar, TextEdit, Preview,    │
│  PasswordApp, LoginWindow                               │
│  import SwiftUI  ← same API as Apple's                  │
├─────────────────────────────────────────────────────────┤
│  SwiftUI         │  AppKit (NSColor, NSImage shims)     │
│  Charts          │  AVFoundation (AVPlayer, AVQueue)    │
│  SwiftData       │  MediaPlayer (MPNowPlayingInfo)      │
│  (SQLite via     │  KeychainServices (SecItem API)      │
│   CSQLite)       │  UniformTypeIdentifiers (UTType)     │
├─────────────────────────────────────────────────────────┤
│  CloneClient / CloneProtocol — IPC over Unix sockets    │
├─────────────────────────────────────────────────────────┤
│  EngineBridge (UniFFI)    │  AudioBridge (UniFFI)       │
│  CGFloat→Float boundary   │  AVPlayer → Rust CPAL       │
├─────────────────────────────────────────────────────────┤
│  Rust: clone-engine       │  Rust: clone-audio          │
│  wgpu, surface compositor │  CPAL, symphonia decoder    │
│  winit event loop         │                             │
└─────────────────────────────────────────────────────────┘
```

### Daemons

| Daemon | Library | Purpose |
|--------|---------|---------|
| `cloned` | `CloneDaemon` | Now-playing info aggregation, media key routing |
| `keychaind` | `CloneKeychain` | SQLite-backed keychain storage, SecItem API |

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
  └── PasswordApp
```
