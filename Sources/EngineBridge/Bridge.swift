import Foundation
import SwiftUI
import CloneProtocol

/// Converts SwiftUI FlatRenderCommand to UniFFI RenderCommand.
public enum Bridge {
    public static func toEngineCommands(_ flatCommands: [FlatRenderCommand]) -> [RenderCommand] {
        flatCommands.map { cmd in
            let cx = Float(cmd.x), cy = Float(cmd.y), cw = Float(cmd.width), ch = Float(cmd.height)
            switch cmd.kind {
            case .rect(let color):
                return .rect(
                    x: cx, y: cy, w: cw, h: ch,
                    color: color.toEngine()
                )
            case .roundedRect(let radius, let color):
                return .roundedRect(
                    x: cx, y: cy, w: cw, h: ch,
                    radius: Float(radius), color: color.toEngine()
                )
            case .text(let content, let fontSize, let color, let weight, let isIcon):
                return .text(
                    x: cx, y: cy,
                    content: content, fontSize: Float(fontSize),
                    color: color.toEngine(),
                    weight: weight.toEngine(),
                    isIcon: isIcon,
                    maxWidth: nil
                )
            case .shadow(let radius, let blur, let color, let offsetX, let offsetY):
                return .shadow(
                    x: cx, y: cy, w: cw, h: ch,
                    radius: Float(radius), blur: Float(blur), color: color.toEngine(),
                    ox: Float(offsetX), oy: Float(offsetY)
                )
            case .pushClip(let radius):
                return .pushClip(
                    x: cx, y: cy, w: cw, h: ch,
                    radius: Float(radius)
                )
            case .popClip:
                return .popClip
            }
        }
    }

    /// Convert IPC render commands to UniFFI commands, offset by window position.
    public static func ipcToEngine(_ ipcCommands: [IPCRenderCommand], offsetX: Float, offsetY: Float) -> [RenderCommand] {
        ipcCommands.map { cmd in
            switch cmd {
            case .rect(let x, let y, let w, let h, let color):
                return .rect(x: x + offsetX, y: y + offsetY, w: w, h: h, color: color.toEngine())
            case .roundedRect(let x, let y, let w, let h, let radius, let color):
                return .roundedRect(x: x + offsetX, y: y + offsetY, w: w, h: h, radius: radius, color: color.toEngine())
            case .text(let x, let y, let content, let fontSize, let color, let weight, let isIcon, let maxWidth):
                return .text(x: x + offsetX, y: y + offsetY, content: content, fontSize: fontSize,
                            color: color.toEngine(), weight: weight.toEngine(), isIcon: isIcon,
                            maxWidth: maxWidth)
            case .shadow(let x, let y, let w, let h, let radius, let blur, let color, let ox, let oy):
                return .shadow(x: x + offsetX, y: y + offsetY, w: w, h: h,
                              radius: radius, blur: blur, color: color.toEngine(),
                              ox: ox, oy: oy)
            case .pushClip(let x, let y, let w, let h, let radius):
                return .pushClip(x: x + offsetX, y: y + offsetY, w: w, h: h, radius: radius)
            case .popClip:
                return .popClip
            case .image(let textureId, let x, let y, let w, let h):
                return .image(textureId: textureId, x: x + offsetX, y: y + offsetY, w: w, h: h)
            case .registerTexture(let textureId, let width, let height, let rgbaData):
                return .registerTexture(textureId: textureId, width: width, height: height, rgbaData: Data(rgbaData))
            case .unregisterTexture(let textureId):
                return .unregisterTexture(textureId: textureId)
            }
        }
    }

    /// Offset a single IPC command by dy (for title bar offset in local coords).
    public static func offsetIpcCommand(_ cmd: IPCRenderCommand, dy: Float) -> RenderCommand {
        switch cmd {
        case .rect(let x, let y, let w, let h, let color):
            return .rect(x: x, y: y + dy, w: w, h: h, color: color.toEngine())
        case .roundedRect(let x, let y, let w, let h, let radius, let color):
            return .roundedRect(x: x, y: y + dy, w: w, h: h, radius: radius, color: color.toEngine())
        case .text(let x, let y, let content, let fontSize, let color, let weight, let isIcon, let maxWidth):
            return .text(x: x, y: y + dy, content: content, fontSize: fontSize,
                        color: color.toEngine(), weight: weight.toEngine(), isIcon: isIcon,
                        maxWidth: maxWidth)
        case .shadow(let x, let y, let w, let h, let radius, let blur, let color, let ox, let oy):
            return .shadow(x: x, y: y + dy, w: w, h: h,
                          radius: radius, blur: blur, color: color.toEngine(),
                          ox: ox, oy: oy)
        case .pushClip(let x, let y, let w, let h, let radius):
            return .pushClip(x: x, y: y + dy, w: w, h: h, radius: radius)
        case .popClip:
            return .popClip
        case .image(let textureId, let x, let y, let w, let h):
            return .image(textureId: textureId, x: x, y: y + dy, w: w, h: h)
        case .registerTexture(let textureId, let width, let height, let rgbaData):
            return .registerTexture(textureId: textureId, width: width, height: height, rgbaData: Data(rgbaData))
        case .unregisterTexture(let textureId):
            return .unregisterTexture(textureId: textureId)
        }
    }
}

extension Color {
    func toEngine() -> RgbaColor {
        RgbaColor(r: Float(r), g: Float(g), b: Float(b), a: Float(a))
    }
}

extension IPCColor {
    func toEngine() -> RgbaColor {
        RgbaColor(r: r, g: g, b: b, a: a)
    }
}

extension SwiftUI.FontWeight {
    func toEngine() -> FontWeight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}

extension IPCFontWeight {
    func toEngine() -> FontWeight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}

/// Thin UniFFI shim — delegates all work to WindowServer.
@MainActor
public final class DesktopDelegateAdapter: @preconcurrency DesktopDelegate {
    private let windowServer = WindowServer()

    public init() {}

    public func onFrame(surfaceId: UInt64, width: UInt32, height: UInt32) -> [RenderCommand] {
        return []
    }

    public func onCompositeFrame(width: UInt32, height: UInt32) -> [SurfaceFrame] {
        windowServer.compositeFrame(width: CGFloat(width), height: CGFloat(height))
    }

    public func onPointerMove(surfaceId: UInt64, x: Double, y: Double) {
        windowServer.handlePointerMove(x: x, y: y)
    }

    public func onPointerButton(surfaceId: UInt64, button: UInt32, pressed: Bool) {
        windowServer.handlePointerButton(button: button, pressed: pressed)
    }

    public func onKey(surfaceId: UInt64, keycode: UInt32, pressed: Bool) {
        windowServer.handleKey(keycode: keycode, pressed: pressed)
    }

    public func onKeyChar(surfaceId: UInt64, character: String) {
        windowServer.handleKeyChar(character: character)
    }

    public func onScroll(surfaceId: UInt64, deltaX: Double, deltaY: Double) {
        windowServer.handleScroll(deltaX: deltaX, deltaY: deltaY)
    }

    public func wallpaperPath() -> String {
        windowServer.wallpaperPath()
    }
}

/// Launch the desktop. Call from main.swift.
@MainActor public func launchDesktop() throws {
    let delegate = DesktopDelegateAdapter()
    try runDesktop(delegate: delegate)
}
