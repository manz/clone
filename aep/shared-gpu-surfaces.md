# AEP: Shared GPU Surfaces

## Context

Clone apps serialize UI as JSON render commands over Unix sockets. This works for structured UI (rects, text, shadows) but is a dead end for pixel-heavy content — video, images, WebViews, canvas. Sending a 1080p RGBA frame as JSON is 8MB+ per frame. Even binary would require CPU->CPU copy + CPU->GPU upload. The compositor lives in GPU; apps need to render pixels directly to GPU memory the compositor samples.

## Approach: Hybrid Model

The command-based IPC stays for UI. A new **shared surface** channel runs alongside it for pixel content. A window can have both: command-rendered chrome/text + a shared surface region for pixels. The compositor processes them in z-order within the same command stream.

## Phases

### Phase 1: Shared Memory + CPU Upload (make it work)

Foundation — full API/IPC protocol using `mmap` shared memory + `queue.write_texture()`. Not zero-copy but functionally correct and usable immediately.

**IPC protocol** (`Sources/CloneProtocol/Messages.swift`):
- `CompositorMessage.sharedSurfaceCreated(token, width, height, shmPath)`
- `AppMessage.requestSharedSurface(width, height, label)`
- `AppMessage.sharedSurfaceReady(token)` — app signals new frame written

**Compositor** (`Sources/CloneServer/SharedSurfaceManager.swift` — new):
- Allocates `/tmp/clone-surface-{token}` mmap'd files
- Tracks token -> mapped pointer
- Reads pixels on `sharedSurfaceReady` for Rust engine

**Rust engine** (`engine/src/commands.rs`):
- New `RenderCommand::SharedSurface { x, y, w, h, surface_token, pixel_data, pixel_width, pixel_height }`
- Pixel data transits FFI in Phase 1 (ugly but works)

**Renderer** (`engine/src/renderer/shared_surface.rs` — new):
- Modeled on `WallpaperPipeline` — textured quad, cached texture per token
- Uploads RGBA via `queue.write_texture()`, reuses texture if same token/dimensions

**App API** (`Sources/SwiftUI/Views/PixelCanvas.swift` — new, behind `#if canImport(CloneClient)`):
```swift
public class PixelCanvas {
    public let width: Int, height: Int
    public var pixels: UnsafeMutableBufferPointer<UInt8>
    public func present()
}
```

### Phase 2: IOSurface Zero-Copy on macOS (the real deal)

Replace mmap + CPU upload with IOSurface GPU sharing. Zero copy.

**Platform layer** (`engine/src/platform/macos.rs` — new):
- `IOSurfaceCreate` -> get Mach port -> send to app
- `MTLTexture(iosurface:)` -> wrap as wgpu texture via `Device::create_texture_from_hal()` (unsafe)
- Returns `TextureView` the compositor samples directly

**Handle passing**: Compositor creates IOSurface, sends Mach port to app. App calls `IOSurfaceLookupFromMachPort()`, maps as `MTLTexture` for writing.

**Remove pixel_data from FFI**: `RenderCommand::SharedSurface` becomes just `{ token, x, y, w, h }`. Rust looks up the shared GPU buffer by token.

**Fallback**: If wgpu-hal interop proves too fragile, CPU-map the IOSurface + `queue.write_texture()`. On Apple Silicon (unified memory), the CPU map is effectively zero-copy anyway.

### Phase 3: Linux DMA-BUF

Same model, Linux primitives.

**Platform layer** (`engine/src/platform/linux.rs` — new):
- Allocate via GBM (`gbm_bo_create`)
- Export DMA-BUF fd (`gbm_bo_get_fd`)
- Import into Vulkan via `VK_KHR_external_memory_fd`
- Wrap as wgpu texture via wgpu-hal Vulkan backend

**fd passing**: `SCM_RIGHTS` ancillary data on the existing Unix socket. Requires `sendmsg`/`recvmsg` in `WireProtocol`.

### Phase 4: Image Loading

Make `Image("photo.jpg")` render actual images through the shared surface pipeline.

- New `RenderCommand::Image { x, y, w, h, path }` (compositor-internal, no cross-process)
- Image texture cache in renderer (keyed by path)
- `WallpaperPipeline` is the existing reference pattern

## Hybrid Model in Practice

A window with video + UI:
```
RoundedRect (window bg)
Rect + Text (title bar)
SharedSurface(token=42, x=0, y=30, w=640, h=480)  <- video
Text "Now Playing" (overlay on top of video)
Rect + Button (controls)
```

Commands processed in order. `SharedSurface` draws the shared texture as a textured quad. Subsequent commands draw on top. Z-ordering preserved naturally.

## What Doesn't Change

- Existing command-based IPC — all current apps keep working
- `composite_window.wgsl` — composites TextureViews regardless of source
- `SurfaceCompositor` composite pass — shared surfaces blit into window offscreen textures
- All current apps (Finder, Dock, MenuBar, Settings) — pure command rendering

## Key Files

| File | Change |
|------|--------|
| `engine/src/commands.rs` | Add `SharedSurface`, `Image` variants |
| `engine/src/renderer/shared_surface.rs` | New — textured quad pipeline (like wallpaper.rs) |
| `engine/src/renderer/mod.rs` | Wire SharedSurface into render loop |
| `engine/src/platform/mod.rs` | New — platform trait for GPU buffer sharing |
| `engine/src/platform/macos.rs` | New — IOSurface + Metal interop |
| `engine/src/platform/linux.rs` | New — DMA-BUF + Vulkan interop |
| `Sources/CloneProtocol/Messages.swift` | Surface negotiation messages |
| `Sources/CloneServer/SharedSurfaceManager.swift` | New — shared memory lifecycle |
| `Sources/SwiftUI/Views/PixelCanvas.swift` | New — app-facing pixel rendering API |
| `Sources/EngineBridge/Bridge.swift` | Wire shared surfaces into SurfaceFrame |

## Dependencies

- Phase 1: None (mmap, existing wgpu)
- Phase 2: `objc2-io-surface`, `objc2-metal` crates; wgpu-hal unsafe interop
- Phase 3: `gbm` + `ash` crates; socket ancillary data

## Risk

The biggest technical risk is Phase 2's wgpu-hal `create_texture_from_hal()` with an external MTLTexture. If fragile, the fallback (CPU-map IOSurface + `queue.write_texture`) is still vastly better than JSON — one memcpy vs encode/decode/multiple copies, and on Apple Silicon unified memory it's effectively free.
