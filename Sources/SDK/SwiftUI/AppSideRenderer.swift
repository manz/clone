import Foundation
import CloneClient
import CloneProtocol
import CloneRender
import SharedSurface
import QuartzCore

/// Manages app-side rendering: drives frame loop via CADisplayLink,
/// renders view tree through the headless GPU renderer, and writes
/// pixels to a shared memory surface for the compositor.
@MainActor
final class AppSideRenderer: NSObject {
    private let client: AppClient
    private var renderer: AppRenderer?
    private var surface: SharedSurface?
    private var displayLink: CADisplayLink?
    private var needsRender: Bool = true
    private var width: CGFloat = 0
    private var height: CGFloat = 0
    private var scale: CGFloat = 2.0
    private var shmName: String?
    /// Use transparent background for overlay surfaces (dock, menubar, loginWindow).
    var transparentBackground: Bool = false

    /// Closure that builds the current frame's render commands.
    /// Called only when the surface needs redrawing.
    var buildFrame: ((_ width: CGFloat, _ height: CGFloat) -> [IPCRenderCommand])?

    init(client: AppClient) {
        self.client = client
        super.init()
    }

    /// Start app-side rendering. Creates the GPU device, shared surface,
    /// and begins the display link.
    func start(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height

        // Create headless GPU renderer
        do {
            renderer = try AppRenderer()
        } catch {
            fputs("[AppSideRenderer] Failed to create GPU renderer: \(error)\n", stderr)
            return
        }

        // Create shared memory surface
        let name = "clone-surface-\(ProcessInfo.processInfo.processIdentifier)"
        shmName = name
        let physW = Int(width * scale)
        let physH = Int(height * scale)
        guard let shm = SharedSurface(name: name, width: physW, height: physH, create: true) else {
            fputs("[AppSideRenderer] Failed to create shared surface\n", stderr)
            return
        }
        surface = shm

        // Tell compositor about the surface
        client.send(.surfaceCreated(shmName: name, width: UInt32(physW), height: UInt32(physH)))
        fputs("[AppSideRenderer] Started: \(name) \(physW)x\(physH)\n", stderr)

        // Start display link
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .default)
        displayLink = link
    }

    /// Mark the surface as needing a redraw (called on state changes).
    func setNeedsDisplay() {
        needsRender = true
    }

    /// Handle resize from compositor.
    func resize(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
        let physW = Int(width * scale)
        let physH = Int(height * scale)
        if surface?.resize(width: physW, height: physH) == true {
            client.send(.surfaceResized(width: UInt32(physW), height: UInt32(physH)))
            needsRender = true
        }
    }

    /// Stop rendering and clean up.
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        surface = nil
        renderer = nil
    }

    @objc private func tick() {
        guard needsRender else { return }
        guard let renderer, let surface, let buildFrame else { return }
        guard width > 0 && height > 0 else { return }
        needsRender = false

        // Build render commands from the view tree
        let ipcCommands = buildFrame(width, height)

        // Convert IPC commands to engine commands
        let commands = ipcCommands.map { $0.toRenderCommand() }

        // Render to pixels via headless GPU
        let pixelData: Data
        do {
            if transparentBackground {
                pixelData = try renderer.renderToPixelsTransparent(
                    commands: commands,
                    width: UInt32(width),
                    height: UInt32(height),
                    scale: Float(scale)
                )
            } else {
                pixelData = try renderer.renderToPixels(
                    commands: commands,
                    width: UInt32(width),
                    height: UInt32(height),
                    scale: Float(scale)
                )
            }
        } catch {
            fputs("[AppSideRenderer] Render failed: \(error)\n", stderr)
            return
        }

        // Copy pixels to shared memory back buffer
        guard let backBuf = surface.backBuffer() else { return }
        let physW = Int(width * scale)
        let physH = Int(height * scale)
        let shmStride = surface.stride
        let srcStride = physW * 4

        pixelData.withUnsafeBytes { src in
            guard let srcBase = src.baseAddress else { return }
            if shmStride == srcStride {
                backBuf.copyMemory(from: srcBase, byteCount: min(src.count, surface.bufferSize))
            } else {
                for row in 0..<physH {
                    let srcOffset = row * srcStride
                    let dstOffset = row * shmStride
                    (backBuf + dstOffset).copyMemory(
                        from: srcBase + srcOffset,
                        byteCount: srcStride
                    )
                }
            }
        }

        // Flip and notify compositor
        surface.flip()
        client.send(.surfaceUpdated)
        fputs("[AppSideRenderer] Frame rendered: \(Int(width))x\(Int(height)) pixels=\(pixelData.count)\n", stderr)
    }
}

// MARK: - IPCRenderCommand → RenderCommand conversion

extension IPCRenderCommand {
    /// Convert an IPC render command to a clone-render RenderCommand.
    func toRenderCommand() -> CloneRender.RenderCommand {
        switch self {
        case .rect(let x, let y, let w, let h, let color):
            return .rect(x: x, y: y, w: w, h: h, color: color.toRgba())
        case .roundedRect(let x, let y, let w, let h, let radius, let color):
            return .roundedRect(x: x, y: y, w: w, h: h, radius: radius, color: color.toRgba())
        case .text(let x, let y, let content, let fontSize, let color, let weight, let maxWidth):
            return .text(x: x, y: y, content: content, fontSize: fontSize, color: color.toRgba(), weight: weight.toFontWeight(), maxWidth: maxWidth)
        case .icon(let name, let style, let x, let y, let w, let h, let color):
            return .icon(name: name, style: style.toIconStyle(), x: x, y: y, w: w, h: h, color: color.toRgba())
        case .shadow(let x, let y, let w, let h, let radius, let blur, let color, let ox, let oy):
            return .shadow(x: x, y: y, w: w, h: h, radius: radius, blur: blur, color: color.toRgba(), ox: ox, oy: oy)
        case .pushClip(let x, let y, let w, let h, let radius):
            return .pushClip(x: x, y: y, w: w, h: h, radius: radius)
        case .popClip:
            return .popClip
        case .image(let textureId, let x, let y, let w, let h):
            return .image(textureId: textureId, x: x, y: y, w: w, h: h)
        case .registerTexture(let textureId, let width, let height, let rgbaData):
            return .registerTexture(textureId: textureId, width: width, height: height, rgbaData: Data(rgbaData))
        case .unregisterTexture(let textureId):
            return .unregisterTexture(textureId: textureId)
        }
    }
}

extension IPCColor {
    func toRgba() -> CloneRender.RgbaColor {
        CloneRender.RgbaColor(r: r, g: g, b: b, a: a)
    }
}

extension IPCFontWeight {
    func toFontWeight() -> CloneRender.FontWeight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}

extension IPCIconStyle {
    func toIconStyle() -> CloneRender.IconStyle {
        switch self {
        case .regular: return .regular
        case .fill: return .fill
        case .duotone: return .duotone
        case .thin: return .thin
        case .light: return .light
        case .bold: return .bold
        }
    }
}
