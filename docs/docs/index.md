# Clone

A macOS desktop environment for Linux — built from scratch with Swift and Rust.

Clone (codename **Aquax**) is a compositor, window manager, and UI framework that replicates the macOS experience on Linux. Swift handles UI logic (layout, DSL, window chrome, app lifecycle) and Rust handles GPU rendering (wgpu/Metal). Apps run as separate processes communicating with the compositor over Unix domain sockets.

## Design Goals

- **API fidelity** — the SDK surface is identical to Apple's SwiftUI and AppKit. App code compiles against both Clone and real Apple frameworks with only `#if canImport(CloneClient)` guards.
- **Native performance** — GPU-accelerated rendering via wgpu (Vulkan on Linux, Metal on macOS). Per-window offscreen textures composited into a single output.
- **Process isolation** — each app runs in its own process. The compositor manages windows and routes input over IPC.
- **Linux-first** — targets Linux as the primary platform. Apps live in `/Applications/*.app/` bundles, frameworks in `/System/Library/Frameworks/`.

## Module Stack

```
┌─────────────────────────────────────────────────────────┐
│  Apps (Finder, Settings, Dock, MenuBar)                 │
│  import SwiftUI  ← same API as Apple's                  │
├─────────────────────────────────────────────────────────┤
│  SwiftUI module        │  AppKit module (NSColor shim)  │
│  Charts module         │  AVFoundation (audio)          │
│  SwiftData (SQLite)    │  MediaPlayer (now playing)     │
├─────────────────────────────────────────────────────────┤
│  CloneClient / CloneProtocol — IPC over Unix sockets    │
├─────────────────────────────────────────────────────────┤
│  EngineBridge (UniFFI) — CGFloat→Float at boundary      │
├─────────────────────────────────────────────────────────┤
│  Rust engine: wgpu renderer, surface compositor, winit  │
└─────────────────────────────────────────────────────────┘
```

## Quick Start

```bash
# macOS development
make all          # Build everything (Rust + Swift)
make sdk          # Assemble .framework bundles
swift run CloneDesktop

# Linux (Docker)
make docker-sdk   # Build SDK for Linux in container
```
