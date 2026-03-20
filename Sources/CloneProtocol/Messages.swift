import Foundation

/// Socket path for the compositor.
public let compositorSocketPath = "/tmp/clone-compositor.sock"

// MARK: - Render command (Codable, shared between processes)

public struct IPCColor: Codable, Equatable, Sendable {
    public let r: Float, g: Float, b: Float, a: Float
    public init(r: Float, g: Float, b: Float, a: Float) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }
}

public enum IPCFontWeight: String, Codable, Sendable {
    case regular, medium, semibold, bold
}

public enum IPCRenderCommand: Codable, Sendable {
    case rect(x: Float, y: Float, w: Float, h: Float, color: IPCColor)
    case roundedRect(x: Float, y: Float, w: Float, h: Float, radius: Float, color: IPCColor)
    case text(x: Float, y: Float, content: String, fontSize: Float, color: IPCColor, weight: IPCFontWeight, isIcon: Bool = false)
    case shadow(x: Float, y: Float, w: Float, h: Float, radius: Float, blur: Float, color: IPCColor, ox: Float, oy: Float)
    case pushClip(x: Float, y: Float, w: Float, h: Float, radius: Float)
    case popClip
}

// MARK: - Surface types

/// How the compositor treats a surface.
public enum SurfaceRole: String, Codable, Sendable {
    /// Normal app window — gets chrome (title bar, traffic lights, shadow), draggable, resizable.
    case window
    /// Dock — pinned to bottom, above all windows, no chrome.
    case dock
    /// Menu bar — pinned to top, topmost, no chrome.
    case menubar
}

// MARK: - Messages: App → Compositor

public enum AppMessage: Codable, Sendable {
    /// App registers itself. Role determines how the compositor handles the surface.
    case register(appId: String, title: String, width: Float, height: Float, role: SurfaceRole)
    /// App sends its render commands for the current frame.
    case frame(commands: [IPCRenderCommand])
    /// App requests to update its window title.
    case setTitle(title: String)
    /// App requests to close its window.
    case close
    /// App handled a tap at the given coordinates.
    case tapHandled
    /// Dock requests the compositor to launch an app binary.
    case launchApp(appId: String)
    /// Dock requests the compositor to restore a minimized window.
    case restoreApp(appId: String)
}

// MARK: - Messages: Compositor → App

public enum CompositorMessage: Codable, Sendable {
    /// Surface was created with the given ID and size.
    case windowCreated(windowId: UInt64, width: Float, height: Float)
    /// Surface was resized.
    case resize(width: Float, height: Float)
    /// Request a frame render — app should respond with .frame
    case requestFrame(width: Float, height: Float)
    /// Pointer moved (local coordinates for windows, screen coordinates for dock/menubar).
    case pointerMove(x: Float, y: Float)
    /// Pointer button event.
    case pointerButton(button: UInt32, pressed: Bool, x: Float, y: Float)
    /// Key event.
    case key(keycode: UInt32, pressed: Bool)
    /// Compositor tells the app which app is focused (for menubar display).
    case focusedApp(name: String)
    /// Compositor tells the dock which apps have minimized windows.
    case minimizedApps(appIds: [String])
}

// MARK: - Wire format: 4-byte length prefix + JSON

public enum WireProtocol {
    public static func encode<T: Encodable>(_ message: T) throws -> Data {
        let json = try JSONEncoder().encode(message)
        var length = UInt32(json.count).bigEndian
        var data = Data(bytes: &length, count: 4)
        data.append(json)
        return data
    }

    public static func decode<T: Decodable>(_ type: T.Type, from buffer: Data) -> (T, Int)? {
        guard buffer.count >= 4 else { return nil }
        let length = buffer.withUnsafeBytes {
            $0.load(as: UInt32.self).bigEndian
        }
        let totalLength = 4 + Int(length)
        guard buffer.count >= totalLength else { return nil }
        let jsonData = buffer.subdata(in: 4..<totalLength)
        guard let message = try? JSONDecoder().decode(T.self, from: jsonData) else { return nil }
        return (message, totalLength)
    }
}
