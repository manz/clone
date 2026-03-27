import Foundation
import CloneClient
import CloneProtocol
import CloneRender
import QuartzCore

/// Manages app-side rendering: drives frame loop via CADisplayLink,
/// renders view tree through the headless GPU renderer into IOSurfaces,
/// and signals the compositor. Zero-copy via Mach port transfer.
@MainActor
final class AppSideRenderer: NSObject {
    private let client: AppClient
    private var renderer: AppRenderer?
    private var displayLink: CADisplayLink?
    private var needsRender: Bool = true
    private var width: CGFloat = 0
    private var height: CGFloat = 0
    private var scale: CGFloat = 2.0
    private var currentIOSurfaceId: UInt32 = 0
    /// Use transparent background for overlay surfaces (dock, menubar, loginWindow).
    var transparentBackground: Bool = false

    /// Closure that builds the current frame's render commands.
    var buildFrame: ((_ width: CGFloat, _ height: CGFloat) -> [IPCRenderCommand])?

    init(client: AppClient) {
        self.client = client
        super.init()
    }

    func start(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height

        do {
            renderer = try AppRenderer()
        } catch {
            fputs("[AppSideRenderer] Failed to create GPU renderer: \(error)\n", stderr)
            return
        }

        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .default)
        displayLink = link
    }

    func setNeedsDisplay() {
        needsRender = true
    }

    func resize(width: CGFloat, height: CGFloat) {
        guard width != self.width || height != self.height else {
            needsRender = true
            return
        }
        self.width = width
        self.height = height
        needsRender = true
        // Don't render synchronously — let the display link handle it.
        // The compositor stretches the old content as fallback until we catch up.
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        renderer = nil
    }

    @objc private func tick() {
        guard needsRender else { return }
        guard let renderer, let buildFrame else { return }
        guard width > 0 && height > 0 else { return }
        needsRender = false

        let ipcCommands = buildFrame(width, height)
        let commands = ipcCommands.map { $0.toRenderCommand() }

        let iosurfaceId: UInt32
        do {
            iosurfaceId = try renderer.render(
                commands: commands,
                width: UInt32(width),
                height: UInt32(height),
                scale: Float(scale),
                transparent: transparentBackground
            )
        } catch {
            fputs("[AppSideRenderer] Render failed: \(error)\n", stderr)
            return
        }

        // If textures were reallocated (first frame or resize), send BOTH Mach ports
        // BEFORE sending the JSON metadata. The compositor's Mach receiver thread
        // imports the IOSurfaces, making IOSurfaceLookup work when the engine tries.
        #if canImport(Darwin)
        if renderer.takeTexturesChanged() {
            for i: UInt32 in 0..<2 {
                let port = renderer.machPortAt(index: i)
                if port != 0 {
                    client.sendIOSurfaceMachPort(port)
                }
            }
            // Give the compositor's Mach receiver thread time to import.
            // mach_msg is fast but the receiver runs on a background thread.
            usleep(1000) // 1ms
        }
        #endif

        // Notify compositor of the current front surface
        let physW = UInt32(width * scale)
        let physH = UInt32(height * scale)
        if currentIOSurfaceId == 0 {
            client.send(.surfaceCreated(iosurfaceId: iosurfaceId, width: physW, height: physH))
        } else if iosurfaceId != currentIOSurfaceId {
            client.send(.surfaceResized(iosurfaceId: iosurfaceId, width: physW, height: physH))
        }
        currentIOSurfaceId = iosurfaceId

        client.send(.surfaceUpdated)
    }
}

// MARK: - IPCRenderCommand → RenderCommand conversion

extension IPCRenderCommand {
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
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
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
