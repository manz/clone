# Rendering Pipeline

Each app renders its own pixels via a headless wgpu device (`clone-render` crate). The compositor just composites the resulting textures — it never renders app content.

See [Architecture](architecture.md) for the full pipeline diagram.

## App-Side Rendering

Apps drive their own frame loop via `CADisplayLink` (60fps timer). When state changes, the display link tick rebuilds the view tree, runs layout, flattens to render commands, and renders into an IOSurface-backed GPU texture. The compositor imports the IOSurface by Mach port — zero copies.

```
CADisplayLink tick
→ buildFrame(width, height)
→ ViewNode tree → Layout → LayoutNode tree
→ CommandFlattener → FlatRenderCommand[]
→ Convert to RenderCommand[] (clone-render)
→ HeadlessDevice.render() → wgpu GPU render into IOSurface
→ Send .surfaceUpdated via IPC (lightweight signal, no pixel data)
→ Compositor: samples the IOSurface texture directly
```

### HeadlessDevice

`render/src/headless.rs` — creates a headless wgpu device (no window), double-buffered IOSurface textures, and the full `DesktopRenderer` pipeline. Each app has its own instance.

- **Double-buffered**: app renders to back texture, compositor reads front. Swap on each frame.
- **Only-grow allocation**: IOSurfaces are only reallocated when the window grows beyond current allocation. Shrinking reuses existing surfaces (no Mach port churn).
- **No GPU sync wait**: `queue.submit()` returns immediately. Double-buffering ensures the compositor reads a complete frame.

### IOSurface Sharing (macOS)

`wgpu-iosurface` crate wraps IOSurface as wgpu textures via the Metal HAL. Cross-process sharing uses Mach ports:

1. App creates IOSurface → `IOSurfaceCreateMachPort` → Mach port
2. App sends port to compositor via bootstrap-server Mach channel
3. Compositor receives port → `IOSurfaceLookupFromMachPort` → imports IOSurface
4. Rust engine: `SharedTexture::from_id()` wraps as wgpu texture for compositing

On Linux (future): dmabuf + SCM_RIGHTS over the Unix socket — same `SharedTexture` abstraction.

## Swift Side

### ViewNode → LayoutNode

Two-pass layout:

1. **Measure pass** (`Layout.measure`) — bottom-up, asks each node for its desired size given a `SizeConstraint`. Text nodes call `TextMeasurer.measure()` via FFI to cosmic-text.

2. **Layout pass** (`Layout.layout`) — top-down, assigns absolute `LayoutFrame` positions. VStack/HStack children measured with remaining space. ScrollView lays out content with unbounded constraint in scroll axes.

### LayoutNode → FlatRenderCommand

`CommandFlattener.flatten()` walks the `LayoutNode` tree and emits flat, absolute-positioned draw instructions:

- Text: only sends `maxWidth` when text overflows its frame
- Opacity: multiplied through the tree
- Clipping: `pushClip`/`popClip` pairs flush batches at clip boundaries
- Shadows: emitted before their child content
- Raster images: `RegisterTexture` (once via `ImageTextureCache`) + `Image` draw command

### Command Conversion

`FlatRenderCommand` → `IPCRenderCommand` → `CloneRender.RenderCommand`. The conversion is mechanical (CGFloat→Float, enum mapping). `toIPCCommands()` handles multi-command expansion (e.g. RegisterTexture + Image for raster images).

## wgpu Renderer (clone-render)

The `clone-render` crate contains the full GPU rendering pipeline, extracted from the engine so apps can link it independently.

### Pipelines

| Pipeline | File | Purpose |
|----------|------|---------|
| RectPipeline | `rect.rs` | Solid + rounded rectangles (instanced) |
| ShadowPipeline | `shadow.rs` | Drop shadows (instanced) |
| TextRenderer | `text.rs` | Glyph atlas + SDF text rendering |
| IconPipeline | `icon.rs` | Phosphor SVG icon rasterization + caching |
| ImagePipeline | `image.rs` | Raster image textured quads (JPEG/PNG/GIF/BMP) |
| WallpaperPipeline | `wallpaper.rs` | Fullscreen wallpaper |
| BlurPipeline | `blur.rs` | Dual-Kawase blur (for glassmorphism) |

### Buffer Strategy

Solid rects and rounded rects use separate instance buffers to avoid `queue.write_buffer` overwrites within the same command encoder.

### DPI Handling

Swift uses logical pixels (`CGFloat`). The renderer multiplies by scale factor. Shadow blur/radius are not DPI-scaled.

## Surface Compositor

The compositor (`engine/src/surface_compositor.rs`) blends all window textures onto the screen:

- **Chrome surfaces**: title bar, traffic lights, shadows — rendered by the compositor's own `DesktopRenderer`
- **Content surfaces**: IOSurface textures from apps — sampled directly, zero-copy
- **Overlay surfaces**: dock, menubar — rendered by their apps with transparent backgrounds

The composite shader (`composite_window.wgsl`) applies SDF rounded-corner masking, shadow with offset/blur, and premultiplied alpha blending. Shadows only render for surfaces with `shadow_expand > 0` (windows, not overlays).

## Text Rendering

Text goes through cosmic-text twice:

1. **Measurement** (clone-text crate) — called from Swift via FFI during layout. Returns (width, height). Supports word wrapping via `max_width` and cursor positioning.
2. **Shaping** (clone-render) — shapes text into `GlyphInstance[]` for GPU rendering. Each glyph is rasterized into a texture atlas.

Both paths use bundled Inter font files (Regular, Medium, SemiBold, Bold) plus Iosevka for monospace.

## Hit Testing

Hit test results are three-state:

- **`.tap(id, frame)`** — actionable hit, fire the tap handler
- **`.absorbed`** — opaque view consumed the event, no handler found. Prevents leak-through to views behind.
- **`nil`** — miss, pass through to the next window

When a child returns `.absorbed`, the search continues upward to ancestor `.onTap` nodes. This means buttons with opaque backgrounds work correctly: the background absorbs (blocking leak-through), the button's tap handler fires.

## ScrollView

ScrollView supports `.horizontal`, `.vertical`, or `[.horizontal, .vertical]` (dual-axis). The `ScrollRegistry` tracks separate X/Y offsets per scroll view. Layout uses unbounded constraints in scroll axes and wraps content in a `.clipped` node. Scrollbar indicators appear for each overflowing axis.

## Lazy List

`List(data) { row }` defers row closure evaluation via `LazyRowRegistry`. The layout engine only builds ViewNodes for visible rows plus a 2-row buffer, using uniform row height estimated from the first row. Off-screen rows are evicted from the cache. This reduces per-frame work from O(n) to O(visible).
