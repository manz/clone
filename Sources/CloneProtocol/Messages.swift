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
    case text(x: Float, y: Float, content: String, fontSize: Float, color: IPCColor, weight: IPCFontWeight)
}

// MARK: - Messages: App → Compositor

public enum AppMessage: Codable, Sendable {
    /// App registers itself with the compositor.
    case register(appId: String, title: String, width: Float, height: Float)
    /// App sends its render commands for the current frame.
    case frame(commands: [IPCRenderCommand])
    /// App requests to update its window title.
    case setTitle(title: String)
    /// App requests to close its window.
    case close
    /// App handled a tap at the given coordinates.
    case tapHandled
}

// MARK: - Messages: Compositor → App

public enum CompositorMessage: Codable, Sendable {
    /// Window was created with the given ID and size.
    case windowCreated(windowId: UInt64, width: Float, height: Float)
    /// Window was resized.
    case resize(width: Float, height: Float)
    /// Request a frame render — app should respond with .frame
    case requestFrame(width: Float, height: Float)
    /// Pointer moved within the app's content area (local coordinates).
    case pointerMove(x: Float, y: Float)
    /// Pointer button event.
    case pointerButton(button: UInt32, pressed: Bool, x: Float, y: Float)
    /// Key event.
    case key(keycode: UInt32, pressed: Bool)
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

    /// Try to decode a message from a buffer. Returns (message, bytesConsumed) or nil if incomplete.
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
