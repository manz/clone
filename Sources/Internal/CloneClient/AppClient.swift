import Foundation
import PosixShim
import CloneProtocol

/// Client library for apps to connect to the Clone compositor.
@MainActor
public final class AppClient {
    var socketFd: Int32 = -1
    private var readBuffer = Data()
    public private(set) var windowId: UInt64 = 0
    #if canImport(Darwin)
    /// Mach send port for IOSurface transfer to compositor.
    private var machSendPort: UInt32 = 0
    #endif
    public private(set) var width: Float = 0
    public private(set) var height: Float = 0
    public internal(set) var isConnected = false
    public private(set) var mouseX: Float = 0
    public private(set) var mouseY: Float = 0

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
    /// Callback for scroll wheel events.
    public var onScroll: (@MainActor (Float, Float) -> Void)?
    /// Callback for color scheme changes.
    public var onColorScheme: (@MainActor (Bool) -> Void)?
    /// Callback when window is created.
    public var onWindowCreated: (@MainActor (UInt64, Float, Float) -> Void)?
    /// Callback when compositor reports focused app name (for menubar).
    public var onFocusedApp: (@MainActor (String) -> Void)?
    /// Callback when compositor reports minimized app IDs (for dock).
    /// Callback when compositor reports minimized windows (for dock).
    public var onMinimizedWindows: (@MainActor ([MinimizedWindowInfo]) -> Void)?
    /// Callback when compositor sends a window thumbnail PNG (for dock).
    public var onWindowThumbnail: (@MainActor (UInt64, Data) -> Void)?
    /// Callback when compositor reports running apps (for dock).
    public var onRunningApps: (@MainActor ([RunningAppInfo]) -> Void)?
    /// Callback when compositor sends app menus.
    public var onAppMenus: (@MainActor (String, [AppMenu]) -> Void)?
    /// Callback when a menu item is selected.
    public var onMenuAction: (@MainActor (String) -> Void)?
    /// Callback for open panel result.
    public var onOpenPanelResult: (@MainActor (String?) -> Void)?
    /// Callback when window is closed by compositor.
    public var onWindowClosed: (@MainActor () -> Void)?
    /// Callback when compositor requests sheet content at the given size.
    public var onSheetFrameRequest: (@MainActor (Float, Float) -> [IPCRenderCommand])?
    /// Callback when user clicks the sheet backdrop.
    public var onSheetBackdropTapped: (@MainActor () -> Void)?
    /// Callback for pointer button events within sheet bounds (sheet-local coords).
    public var onSheetPointerButton: (@MainActor (UInt32, Bool, Float, Float) -> Void)?
    /// Callback when compositor tells the app to open a file.
    public var onOpenFile: (@MainActor (String) -> Void)?
    /// Callback for AvocadoEvents routed through the compositor.
    public var onAvocadoEvent: (@MainActor (AvocadoEvent) -> Void)?

    public init() {}

    public func connect(appId: String, title: String, width: Float, height: Float, role: SurfaceRole = .window) throws {
        let path = compositorSocketPath
        #if canImport(Darwin)
        socketFd = socket(AF_UNIX, SOCK_STREAM, 0)
        #else
        socketFd = socket(AF_UNIX, Int32(SOCK_STREAM.rawValue), 0)
        #endif
        guard socketFd >= 0 else { throw NSError(domain: "AppClient", code: 1) }

        // Prevent SIGPIPE on write to closed socket — return EPIPE instead
        #if canImport(Darwin)
        var on: Int32 = 1
        setsockopt(socketFd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        #else
        signal(SIGPIPE, SIG_IGN)
        #endif

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
                posix_connect(socketFd, sockPtr, addrLen)
            }
        }
        guard result == 0 else { throw NSError(domain: "AppClient", code: 2) }
        isConnected = true

        // Register with compositor
        send(.register(appId: appId, title: title, width: width, height: height, role: role))

        #if canImport(Darwin)
        // Look up the Mach port for IOSurface transfer
        let (machOk, port) = posix_mach_lookup_port("com.clone.compositor.surfaces")
        if machOk {
            machSendPort = port
        }
        #endif

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

    #if canImport(Darwin)
    /// Send an IOSurface Mach port to the compositor via the Mach channel.
    /// Call this alongside the regular .surfaceCreated IPC message.
    public func sendIOSurfaceMachPort(_ machPort: UInt32) {
        guard machSendPort != 0 else { return }
        _ = posix_mach_send_port(dest: machSendPort, port: machPort)
    }
    #endif

    private let sendQueue = DispatchQueue(label: "clone.appclient.send")

    public func send(_ message: AppMessage) {
        guard let data = try? WireProtocol.encode(message) else { return }
        sendQueue.async { [fd = self.socketFd] in
            data.withUnsafeBytes { ptr in
                var written = 0
                while written < data.count {
                    let n = posix_write(fd, ptr.baseAddress! + written, data.count - written)
                    if n <= 0 { break }
                    written += n
                }
            }
        }
    }

    /// Send a message with an attached file descriptor via SCM_RIGHTS (Linux DMA-BUF).
    /// The fd is closed after sending — caller must NOT close it.
    public func sendWithFd(_ message: AppMessage, fd attachedFd: Int32) {
        guard let data = try? WireProtocol.encode(message) else {
            posix_close(attachedFd)
            return
        }
        sendQueue.async { [sockFd = self.socketFd] in
            data.withUnsafeBytes { ptr in
                guard let base = ptr.baseAddress else { return }
                _ = posix_sendmsg_fd(sockFd, base, data.count, attachedFd)
            }
            // Close after sendmsg — kernel has dup'd it for the receiver
            posix_close(attachedFd)
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
            if let commands = onFrameRequest?(w, h) {
                send(.frame(commands: commands))
            }

        case .requestFrame(let w, let h):
            width = w
            height = h
            if let commands = onFrameRequest?(w, h) {
                send(.frame(commands: commands))
            }

        case .pointerMove(let x, let y):
            mouseX = x
            mouseY = y
            onPointerMove?(x, y)

        case .pointerButton(let button, let pressed, let x, let y):
            onPointerButton?(button, pressed, x, y)

        case .key(let keycode, let pressed):
            onKey?(keycode, pressed)

        case .keyChar(let character):
            onKeyChar?(character)

        case .scroll(let dx, let dy):
            onScroll?(dx, dy)

        case .colorScheme(let dark):
            onColorScheme?(dark)

        case .focusedApp(let name):
            onFocusedApp?(name)

        case .minimizedWindows(let windows):
            onMinimizedWindows?(windows)

        case .windowThumbnail(let windowId, let pngData):
            onWindowThumbnail?(windowId, pngData)

        case .runningApps(let apps):
            onRunningApps?(apps)

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

        case .requestSheetFrame(let w, let h):
            if let commands = onSheetFrameRequest?(w, h) {
                send(.sheetFrame(commands: commands))
            }

        case .sheetBackdropTapped:
            onSheetBackdropTapped?()

        case .sheetPointerButton(let button, let pressed, let x, let y):
            onSheetPointerButton?(button, pressed, x, y)

        case .openFile(let path):
            onOpenFile?(path)

        case .avocadoEvent(let event):
            onAvocadoEvent?(event)

        case .surfaceReady:
            break // handled by app-side rendering (Phase 5)

        case .requestResize:
            break // handled by app-side rendering (Phase 5)
        }
    }

    /// Run the event loop. Blocking socket read on a background thread,
    /// message handling dispatched to MainActor. Main thread stays free
    /// for URLSession, async/await, timers.
    public func runLoop() {
        let fd = socketFd

        // Blocking read loop on background thread
        Thread.detachNewThread {
            // Set blocking
            let flags = fcntl(fd, F_GETFL)
            fcntl(fd, F_SETFL, flags & ~O_NONBLOCK)

            var readBuf = Data()
            var buf = [UInt8](repeating: 0, count: 65536)
            while true {
                let n = posix_read(fd, &buf, buf.count)
                if n <= 0 { break }
                readBuf.append(contentsOf: buf[0..<n])

                // Decode all complete messages
                var batch: [CompositorMessage] = []
                while let (msg, consumed) = WireProtocol.decode(CompositorMessage.self, from: readBuf) {
                    readBuf = readBuf.subdata(in: consumed..<readBuf.count)
                    batch.append(msg)
                }

                // If there's an incomplete message at the tail, keep reading until it's whole.
                // This prevents large messages (e.g. thumbnails) from stalling behind tiny
                // per-frame messages that trickle in one at a time.
                while readBuf.count >= 4 {
                    let needed = Int(readBuf.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }) + 4
                    if readBuf.count >= needed { break }
                    let more = posix_read(fd, &buf, buf.count)
                    if more <= 0 { break }
                    readBuf.append(contentsOf: buf[0..<more])
                    // Decode any messages that became complete
                    while let (msg, consumed) = WireProtocol.decode(CompositorMessage.self, from: readBuf) {
                        readBuf = readBuf.subdata(in: consumed..<readBuf.count)
                        batch.append(msg)
                    }
                }

                if !batch.isEmpty {
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated {
                            for message in batch {
                                self.handle(message)
                            }
                        }
                    }
                }
            }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.isConnected = false
                }
            }
        }

        // Keep main thread alive for GCD callbacks
        dispatchMain()
    }

    public func disconnect() {
        if isConnected {
            send(.close)
        }
        if socketFd >= 0 {
            shutdown(socketFd, Int32(SHUT_RDWR))
            posix_close(socketFd)
            socketFd = -1
        }
        isConnected = false
    }
}

