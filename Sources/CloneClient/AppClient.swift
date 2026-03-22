import Foundation
import PosixShim
import CloneProtocol

/// Client library for apps to connect to the Clone compositor.
@MainActor
public final class AppClient {
    private var socketFd: Int32 = -1
    private var readBuffer = Data()
    public private(set) var windowId: UInt64 = 0
    public private(set) var width: Float = 0
    public private(set) var height: Float = 0
    public private(set) var isConnected = false

    /// Callback when the compositor requests a frame.
    public var onFrameRequest: (@MainActor (Float, Float) -> [IPCRenderCommand])?
    /// Callback for pointer movement (local coords).
    public var onPointerMove: (@MainActor (Float, Float) -> Void)?
    /// Callback for pointer button.
    public var onPointerButton: (@MainActor (UInt32, Bool, Float, Float) -> Void)?
    /// Callback for key events.
    public var onKey: (@MainActor (UInt32, Bool) -> Void)?
    /// Callback for character input (translated from keycode).
    public var onKeyChar: (@MainActor (String) -> Void)?
    /// Callback when window is created.
    public var onWindowCreated: (@MainActor (UInt64, Float, Float) -> Void)?
    /// Callback when compositor reports focused app name (for menubar).
    public var onFocusedApp: (@MainActor (String) -> Void)?
    /// Callback when compositor reports minimized app IDs (for dock).
    public var onMinimizedApps: (@MainActor ([String]) -> Void)?
    /// Callback when compositor sends app menus.
    public var onAppMenus: (@MainActor (String, [AppMenu]) -> Void)?
    /// Callback when a menu item is selected.
    public var onMenuAction: (@MainActor (String) -> Void)?
    /// Callback for open panel result.
    public var onOpenPanelResult: (@MainActor (String?) -> Void)?
    /// Callback when window is closed by compositor.
    public var onWindowClosed: (@MainActor () -> Void)?

    public init() {}

    public func connect(appId: String, title: String, width: Float, height: Float, role: SurfaceRole = .window) throws {
        let path = "/tmp/clone-compositor.sock"
        socketFd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketFd >= 0 else { throw NSError(domain: "AppClient", code: 1) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            path.withCString { cstr in
                _ = memcpy(ptr, cstr, min(path.count, 104))
            }
        }
        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Foundation.connect(socketFd, sockPtr, addrLen)
            }
        }
        guard result == 0 else { throw NSError(domain: "AppClient", code: 2) }
        isConnected = true

        // Register with compositor
        send(.register(appId: appId, title: title, width: width, height: height, role: role))

        // Set non-blocking for initial read
        let flags = fcntl(socketFd, F_GETFL)
        fcntl(socketFd, F_SETFL, flags | O_NONBLOCK)

        // Wait for windowCreated response (poll briefly)
        for _ in 0..<100 {
            poll()
            if windowId != 0 { break }
            usleep(10_000) // 10ms
        }
    }

    public func send(_ message: AppMessage) {
        guard let data = try? WireProtocol.encode(message) else { return }
        data.withUnsafeBytes { ptr in
            _ = posix_write(socketFd, ptr.baseAddress!, data.count)
        }
    }

    /// Poll for incoming messages from the compositor. Non-blocking.
    public func poll() {
        // Set non-blocking for read
        let flags = fcntl(socketFd, F_GETFL)
        fcntl(socketFd, F_SETFL, flags | O_NONBLOCK)

        var buf = [UInt8](repeating: 0, count: 65536)
        let bytesRead = posix_read(socketFd, &buf, buf.count)
        if bytesRead > 0 {
            readBuffer.append(contentsOf: buf[0..<bytesRead])
            while let (msg, consumed) = WireProtocol.decode(CompositorMessage.self, from: readBuffer) {
                readBuffer = readBuffer.subdata(in: consumed..<readBuffer.count)
                handle(msg)
            }
        }
    }

    func handle(_ msg: CompositorMessage) {
        switch msg {
        case .windowCreated(let id, let w, let h):
            windowId = id
            width = w
            height = h
            onWindowCreated?(id, w, h)

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

        case .keyChar(let character):
            onKeyChar?(character)

        case .focusedApp(let name):
            onFocusedApp?(name)

        case .minimizedApps(let appIds):
            onMinimizedApps?(appIds)

        case .appMenus(let appName, let menus):
            onAppMenus?(appName, menus)

        case .menuAction(let itemId):
            onMenuAction?(itemId)

        case .openPanelResult(let path):
            onOpenPanelResult?(path)

        case .windowClosed:
            onWindowClosed?()

        case .terminate:
            isConnected = false
        }
    }

    /// Run the event loop. Blocking read with periodic RunLoop drain for GCD/async.
    public func runLoop() {
        // Set blocking for synchronous reads
        let flags = fcntl(socketFd, F_GETFL)
        fcntl(socketFd, F_SETFL, flags & ~O_NONBLOCK)

        while isConnected {
            // Use select() with timeout so we periodically drain the RunLoop
            var readSet = fd_set()
            fdZero(&readSet)
            fdSet(socketFd, &readSet)
            var timeout = timeval(tv_sec: 0, tv_usec: 16_000) // 16ms

            let ready = select(socketFd + 1, &readSet, nil, nil, &timeout)
            if ready > 0 {
                // Data available — read and process
                var buf = [UInt8](repeating: 0, count: 65536)
                let bytesRead = posix_read(socketFd, &buf, buf.count)
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
            // Drain the RunLoop — processes GCD callbacks, URLSession responses, timers
            while RunLoop.main.run(mode: .default, before: Date()) {}
        }
    }

    public func disconnect() {
        if isConnected {
            send(.close)
        }
        if socketFd >= 0 {
            posix_close(socketFd)
            socketFd = -1
        }
        isConnected = false
    }
}

// MARK: - fd_set helpers (macOS)

private func fdZero(_ set: inout fd_set) {
    bzero(&set, MemoryLayout<fd_set>.size)
}

private func fdSet(_ fd: Int32, _ set: inout fd_set) {
    let intOffset = Int(fd / 32)
    let bitOffset = Int(fd % 32)
    withUnsafeMutableBytes(of: &set) { buf in
        let ints = buf.baseAddress!.assumingMemoryBound(to: Int32.self)
        ints[intOffset] |= Int32(1 << bitOffset)
    }
}
