import Foundation
import CloneProtocol

/// Client library for apps to connect to the Clone compositor.
public final class AppClient {
    private var socketFd: Int32 = -1
    private var readBuffer = Data()
    public private(set) var windowId: UInt64 = 0
    public private(set) var width: Float = 0
    public private(set) var height: Float = 0
    public private(set) var isConnected = false

    /// Callback when the compositor requests a frame.
    public var onFrameRequest: ((Float, Float) -> [IPCRenderCommand])?
    /// Callback for pointer movement (local coords).
    public var onPointerMove: ((Float, Float) -> Void)?
    /// Callback for pointer button.
    public var onPointerButton: ((UInt32, Bool, Float, Float) -> Void)?
    /// Callback for key events.
    public var onKey: ((UInt32, Bool) -> Void)?
    /// Callback when window is created.
    public var onWindowCreated: ((UInt64, Float, Float) -> Void)?
    /// Callback when compositor reports focused app name (for menubar).
    public var onFocusedApp: ((String) -> Void)?
    /// Callback when compositor reports minimized app IDs (for dock).
    public var onMinimizedApps: (([String]) -> Void)?

    public init() {}

    /// Connect to the compositor and register the app.
    public func connect(appId: String, title: String, width: Float, height: Float, role: SurfaceRole = .window) throws {
        socketFd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketFd >= 0 else {
            throw AppClientError.socketFailed
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        compositorSocketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) { pathPtr in
                pathPtr.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
                    _ = strlcpy(dest, ptr, 104)
                }
            }
        }

        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.connect(socketFd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else {
            Darwin.close(socketFd)
            throw AppClientError.connectFailed
        }

        isConnected = true
        self.width = width
        self.height = height

        // Send register message
        send(.register(appId: appId, title: title, width: width, height: height, role: role))
    }

    /// Send a message to the compositor.
    public func send(_ message: AppMessage) {
        guard let data = try? WireProtocol.encode(message) else { return }
        data.withUnsafeBytes { ptr in
            _ = Darwin.write(socketFd, ptr.baseAddress!, data.count)
        }
    }

    /// Poll for incoming messages from the compositor. Non-blocking.
    public func poll() {
        // Set non-blocking for read
        let flags = fcntl(socketFd, F_GETFL)
        fcntl(socketFd, F_SETFL, flags | O_NONBLOCK)

        var buf = [UInt8](repeating: 0, count: 65536)
        let bytesRead = Darwin.read(socketFd, &buf, buf.count)
        if bytesRead > 0 {
            readBuffer.append(contentsOf: buf[0..<bytesRead])
        } else if bytesRead == 0 {
            // Connection closed
            isConnected = false
            return
        }

        // Decode messages
        while let (msg, consumed) = WireProtocol.decode(CompositorMessage.self, from: readBuffer) {
            readBuffer = readBuffer.subdata(in: consumed..<readBuffer.count)
            handle(msg)
        }
    }

    private func handle(_ message: CompositorMessage) {
        switch message {
        case .windowCreated(let wid, let w, let h):
            windowId = wid
            width = w
            height = h
            onWindowCreated?(wid, w, h)

        case .resize(let w, let h):
            width = w
            height = h

        case .requestFrame(let w, let h):
            width = w
            height = h
            if let commands = onFrameRequest?(w, h) {
                send(.frame(commands: commands))
            }

        case .pointerMove(let x, let y):
            onPointerMove?(x, y)

        case .pointerButton(let button, let pressed, let x, let y):
            onPointerButton?(button, pressed, x, y)

        case .key(let keycode, let pressed):
            onKey?(keycode, pressed)

        case .focusedApp(let name):
            onFocusedApp?(name)

        case .minimizedApps(let appIds):
            onMinimizedApps?(appIds)
        }
    }

    /// Run the event loop. Blocks the current thread.
    public func runLoop() {
        // Set blocking for the main loop
        let flags = fcntl(socketFd, F_GETFL)
        fcntl(socketFd, F_SETFL, flags & ~O_NONBLOCK)

        while isConnected {
            var buf = [UInt8](repeating: 0, count: 65536)
            let bytesRead = Darwin.read(socketFd, &buf, buf.count)
            if bytesRead > 0 {
                readBuffer.append(contentsOf: buf[0..<bytesRead])
                while let (msg, consumed) = WireProtocol.decode(CompositorMessage.self, from: readBuffer) {
                    readBuffer = readBuffer.subdata(in: consumed..<readBuffer.count)
                    handle(msg)
                }
            } else {
                isConnected = false
            }
        }
    }

    public func disconnect() {
        if isConnected {
            send(.close)
        }
        if socketFd >= 0 {
            Darwin.close(socketFd)
            socketFd = -1
        }
        isConnected = false
    }

    deinit {
        disconnect()
    }
}

public enum AppClientError: Error {
    case socketFailed
    case connectFailed
}
