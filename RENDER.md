# RENDER.md — Toward a Real Compositor Architecture

## Current State

Today, clone is a **single-process renderer** with a flat command stream:

```
Swift ViewNode tree → CommandFlattener → Vec<RenderCommand> (FFI) → wgpu batched draw
```

Everything lives in one process. The Swift side builds a complete frame as a flat list of
absolute-positioned primitives (Rect, RoundedRect, Shadow, Text, PushClip/PopClip), the Rust
engine walks that list linearly, batches by type, and draws with instanced wgpu calls + scissor
clipping.

This works, but it's fundamentally different from how macOS composites windows. On macOS, each app
renders into its own **offscreen surface** (IOSurface backed by GPU memory), and the WindowServer
composites those surfaces together. Apps never know about each other's pixels.

## Target Architecture

Decouple **window content rendering** from **screen composition** so that:

1. Each window renders into its own offscreen texture (like an IOSurface)
2. A compositor pass blends those textures together with window chrome (shadows, rounded corners)
3. The menubar and dock render into their own surfaces too
4. Only dirty windows re-render; clean windows reuse their cached texture

```
                    ┌─────────────┐
                    │ Swift UI    │  per-window ViewNode trees
                    └──────┬──────┘
                           │ Vec<RenderCommand> per window
                           ▼
               ┌───────────────────────┐
               │  Per-Window Renderer  │  renders commands → offscreen wgpu texture
               │  (one per window)     │  only re-renders if window is dirty
               └───────────┬───────────┘
                           │ wgpu::TextureView per window
                           ▼
               ┌───────────────────────┐
               │     Compositor        │  blends all window textures onto screen
               │                       │  adds shadows, rounded mask, blur
               │                       │  respects z-order, opacity
               └───────────┬───────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │  Surface    │  presented to display
                    └─────────────┘
```

## Implementation Plan

### Phase 1 — Per-Window Offscreen Textures

**Goal:** Each window renders to its own texture instead of directly to the screen.

**Steps:**

1. **Introduce a `WindowSurface` struct** that owns:
   - A `wgpu::Texture` + `TextureView` sized to the window's logical dimensions × scale
   - A dirty flag
   - The window's z-order, position, and size in screen coordinates

2. **Split the frame callback** — instead of one `on_frame()` returning all commands for all
   windows, have `on_frame_for_window(window_id)` return commands for a single window. The Swift
   side already knows which window each command belongs to (it builds per-window ViewNode trees).

3. **Render each dirty window** into its own texture using the existing `DesktopRenderer` pipeline
   (rect, shadow, text). PushClip/PopClip still works within each window's local coordinate space.
   Window-local coordinates mean (0,0) is the window's top-left — no more absolute screen positions
   in the command stream.

4. **Skip clean windows** — if a window hasn't changed since last frame, reuse its texture. This is
   the first real performance win: today every pixel is redrawn every frame.

**Key changes:**
- `commands.rs`: Add `window_id` to the frame protocol, or return `Vec<(WindowId, Vec<RenderCommand>)>`
- `renderer/mod.rs`: `DesktopRenderer::render()` takes a target `TextureView` (offscreen or screen)
- `window.rs`: Maintain a `Vec<WindowSurface>`, render dirty ones, then composite

### Phase 2 — Compositor Pass

**Goal:** A dedicated pass that takes all window textures and composites them onto the screen.

**Steps:**

1. **Write a compositor shader** (`composite_window.wgsl`) that for each window:
   - Samples the window's offscreen texture
   - Applies a rounded-rect SDF mask (window corner radius)
   - Blends with alpha over the background

2. **Draw windows back-to-front** — iterate `WindowSurface` list sorted by z-order, draw a
   screen-space quad textured with each window's offscreen texture.

3. **Move shadows out of per-window rendering** — shadows are a compositor concern. The compositor
   draws a shadow quad *before* the window quad, using the existing `ShadowPipeline`. This means
   windows don't need to know about their own shadows.

4. **Menubar and dock as special surfaces** — they render into their own textures at fixed z-orders
   (above all windows). Same pipeline, just pinned position and z.

**Key changes:**
- New `renderer/compositor.rs` (replace the unused glassmorphism stub)
- New shader `composite_window.wgsl`: textured quad + SDF corner mask
- `ShadowPipeline` moves from per-window to compositor-level
- Remove PushClip/PopClip from the cross-window level (each window clips itself naturally)

### Phase 3 — Dirty Tracking & Partial Redraws

**Goal:** Minimize GPU work by only re-rendering what changed.

**Steps:**

1. **Content-hash the command list** per window — if the commands haven't changed, the window isn't
   dirty. Simple and effective for static windows (most of the time, most windows are idle).

2. **Damage rects** (optional, more complex) — track which region of a window changed and only
   re-render that sub-rect into the offscreen texture. Requires partial clear + scissored render.
   May not be worth the complexity initially.

3. **Compositor-level dirty tracking** — if no window moved, resized, or changed z-order, and no
   window content is dirty, skip the composite pass entirely and present the previous frame.

### Phase 4 — Glassmorphism / Backdrop Blur

**Goal:** Use the multi-surface architecture to enable frosted glass effects.

The existing `BlurPipeline` (dual-Kawase, `blur_down.wgsl`/`blur_up.wgsl`) is already implemented
but unused. With per-window textures and a compositor, it slots in naturally:

1. **Before compositing a blurred window**, take the *current composite so far* (everything behind
   this window) as input
2. **Downsample + blur** that region using the existing `BlurPipeline`
3. **Composite the window** with its blurred backdrop as the background, tinted and masked by the
   window's SDF shape

This is exactly what the existing `compositor.rs` stub was designed for — it just needs real
per-window textures to work with instead of a single frame buffer.

### Phase 5 — Towards Multi-Process (Future)

**Goal:** Each "app" runs in its own process, renders to a shared GPU buffer.

This is the full macOS model and the furthest stretch goal:

1. **Shared GPU memory** — each app process creates a texture (via IOSurface or shared wgpu buffer)
   and renders into it independently
2. **The compositor is a separate process** that reads those shared textures
3. **Mach port IPC** for window metadata (position, size, z-order, visibility)
4. **Apps don't see each other's content** — true security isolation

This phase is architecturally enabled by phases 1-2 (the compositor already treats windows as opaque
textures) but requires significant IPC and process management work beyond rendering.

## Migration Strategy

Each phase is independently shippable and improves the architecture:

- **Phase 1** alone gives dirty tracking and local coordinates (simpler commands, better perf)
- **Phase 2** gives proper z-ordered composition with window-level shadows
- **Phase 3** is pure optimization
- **Phase 4** unlocks the visual effect that motivated `BlurPipeline`
- **Phase 5** is the endgame but optional — the compositor works fine single-process

The existing `DesktopRenderer` (rect, shadow, text pipelines) doesn't need to change much — it just
renders to an offscreen texture instead of the screen. The new work is the compositor pass and the
plumbing to manage per-window surfaces.

## Files That Will Change

| File | Change |
|------|--------|
| `engine/src/commands.rs` | Add window_id, local coordinates |
| `engine/src/window.rs` | WindowSurface management, per-window render loop |
| `engine/src/renderer/mod.rs` | Accept target TextureView, remove cross-window clipping |
| `engine/src/renderer/compositor.rs` | Replace stub with real compositor pass |
| `engine/src/shaders/composite_window.wgsl` | New: textured quad + SDF mask |
| `Sources/DesktopKit/CommandFlattener.swift` | Emit local coords per window |
| `Sources/DesktopKit/Desktop.swift` | Return per-window command lists |
| `engine/src/ffi.rs` | Updated delegate trait for per-window frames |
