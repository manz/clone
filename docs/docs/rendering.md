# Rendering Pipeline

The rendering pipeline transforms SwiftUI view trees into GPU draw calls.

See [Architecture](architecture.md) for the full pipeline diagram. This page covers the Rust engine internals.

## wgpu Renderer

The Rust engine uses wgpu (WebGPU API) for cross-platform GPU rendering. On Linux it targets Vulkan via Mesa; on macOS it uses Metal.

### Buffer Strategy

Solid rects and rounded rects use **separate instance buffers** to avoid `queue.write_buffer` overwrites within the same command encoder. This was a hard-won lesson — sharing a buffer caused visual corruption.

### Batching

Render commands are sorted by type and drawn in instanced batches:

1. Solid rectangles (background fills, borders)
2. Rounded rectangles (buttons, cards, window chrome)
3. Shadows (drop shadows, inset shadows)
4. Text (cosmic-text glyph rendering)

### DPI Handling

Swift uses logical pixels (`CGFloat`). The Rust engine multiplies by `scale_factor()` from winit. Shadow blur and radius are **not** DPI-scaled.

## Surface Compositor

Each window renders to an offscreen texture. The `SurfaceCompositor` blends all window textures onto the final screen output, ordered by z-index.
