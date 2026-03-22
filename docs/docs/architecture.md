# Architecture

Clone splits across two languages: **Swift** for UI logic and **Rust** for GPU rendering.

## Two-Language Split

| Layer | Language | Responsibility |
|-------|----------|----------------|
| UI framework | Swift | View structs, layout engine, ViewBuilder DSL, App protocol |
| Window manager | Swift | Window chrome, hit testing, focus, drag |
| IPC | Swift | Length-prefixed JSON over Unix sockets |
| GPU renderer | Rust | wgpu instanced draws, surface compositor, winit event loop |
| Audio engine | Rust | CPAL audio playback, exposed via UniFFI |

**UniFFI 0.28** bridges Rust and Swift. The `DesktopDelegate` callback trait (Rust) is implemented in Swift (`SwiftDesktopDelegate`). Rust calls Swift to get render commands each frame; Swift calls Rust to start the engine.

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

Length-prefixed JSON over Unix socket (`/tmp/clone-compositor.sock`):

- **AppMessage** (app → compositor): register, frame, setTitle, close, launchApp, restoreApp
- **CompositorMessage** (compositor → app): windowCreated, requestFrame, resize, pointer/key events

## Process Model

Each app runs as a separate process. The compositor manages windows and routes input.

```
CloneDesktop (compositor)
  ├── Dock
  ├── MenuBar
  ├── Finder
  ├── Settings
  ├── cloned (now-playing daemon)
  └── keychaind (keychain daemon)
```
