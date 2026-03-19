import Foundation
import CloneProtocol

/// A connected app process.
public final class ConnectedApp {
    public let windowId: UInt64
    public var appId: String
    public var title: String
    public var width: Float
    public var height: Float
    public private(set) var lastCommands: [IPCRenderCommand] = []

    let fd: Int32
    var readBuffer = Data()
    var readSource: DispatchSourceRead?

    private let lock = NSLock()
    weak var server: CompositorServer?

    init(windowId: UInt64, appId: String, title: String, width: Float, height: Float, fd: Int32) {
        self.windowId = windowId
        self.appId = appId
        self.title = title
        self.width = width
        self.height = height
        self.fd = fd
    }

    func startReading(on queue: DispatchQueue, server: CompositorServer) {
        self.server = server
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.handleReadable()
        }
        source.setCancelHandler { [fd] in
            Darwin.close(fd)
        }
        source.resume()
        readSource = source
    }

    private func handleReadable() {
        var buf = [UInt8](repeating: 0, count: 65536)
        let bytesRead = Darwin.read(fd, &buf, buf.count)
        guard bytesRead > 0 else {
            // Disconnected
            readSource?.cancel()
            readSource = nil
            server?.handleDisconnect(windowId: windowId)
            return
        }

        lock.lock()
        readBuffer.append(contentsOf: buf[0..<bytesRead])

        while let (msg, consumed) = WireProtocol.decode(AppMessage.self, from: readBuffer) {
            readBuffer = readBuffer.subdata(in: consumed..<readBuffer.count)
            lock.unlock()
            server?.handle(message: msg, from: self)
            lock.lock()
        }
        lock.unlock()
    }

    func send(_ message: CompositorMessage) {
        guard let data = try? WireProtocol.encode(message) else { return }
        data.withUnsafeBytes { ptr in
            _ = Darwin.write(fd, ptr.baseAddress!, data.count)
        }
    }

    public func updateCommands(_ commands: [IPCRenderCommand]) {
        lock.lock()
        lastCommands = commands
        lock.unlock()
    }

    public func getCommands() -> [IPCRenderCommand] {
        lock.lock()
        defer { lock.unlock() }
        return lastCommands
    }

    func stop() {
        readSource?.cancel()
        readSource = nil
    }
}

/// Async compositor IPC server using GCD dispatch sources.
public final class CompositorServer {
    private var serverSocket: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private let ioQueue = DispatchQueue(label: "clone.compositor.io", attributes: .concurrent)
    private let lock = NSLock()

    private var apps: [UInt64: ConnectedApp] = [:]
    private var nextWindowId: UInt64 = 1
    private let socketPath: String

    /// Callback when a new app connects (called on ioQueue).
    public var onAppConnected: ((ConnectedApp) -> Void)?
    /// Callback when an app disconnects.
    public var onAppDisconnected: ((UInt64) -> Void)?

    public var connectedApps: [ConnectedApp] {
        lock.lock()
        defer { lock.unlock() }
        return Array(apps.values)
    }

    public init(socketPath: String = compositorSocketPath) {
        self.socketPath = socketPath
    }

    /// Start listening. Returns immediately — I/O is async via GCD.
    public func start() throws {
        unlink(socketPath)

        serverSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverSocket >= 0 else { throw CompositorError.socketFailed }

        let flags = fcntl(serverSocket, F_GETFL)
        _ = fcntl(serverSocket, F_SETFL, flags | O_NONBLOCK)

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) { pathPtr in
                pathPtr.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
                    _ = strlcpy(dest, ptr, 104)
                }
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(serverSocket, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            Darwin.close(serverSocket)
            throw CompositorError.bindFailed
        }

        guard listen(serverSocket, 8) == 0 else {
            Darwin.close(serverSocket)
            throw CompositorError.listenFailed
        }

        // Async accept via GCD
        let source = DispatchSource.makeReadSource(fileDescriptor: serverSocket, queue: ioQueue)
        source.setEventHandler { [weak self] in
            self?.acceptNewConnections()
        }
        source.resume()
        acceptSource = source
    }

    private func acceptNewConnections() {
        while true {
            var clientAddr = sockaddr_un()
            var addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
            let clientFd = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    accept(serverSocket, sockPtr, &addrLen)
                }
            }
            guard clientFd >= 0 else { break }

            let flags = fcntl(clientFd, F_GETFL)
            _ = fcntl(clientFd, F_SETFL, flags | O_NONBLOCK)

            lock.lock()
            let id = nextWindowId
            nextWindowId += 1
            let app = ConnectedApp(
                windowId: id, appId: "pending", title: "Loading...",
                width: 600, height: 400, fd: clientFd
            )
            apps[id] = app
            lock.unlock()

            app.startReading(on: ioQueue, server: self)
        }
    }

    /// Handle a message from an app. Called on the ioQueue.
    func handle(message: AppMessage, from app: ConnectedApp) {
        switch message {
        case .register(let appId, let title, let width, let height):
            app.appId = appId
            app.title = title
            app.width = width
            app.height = height
            app.send(.windowCreated(windowId: app.windowId, width: width, height: height))
            onAppConnected?(app)

        case .frame(let commands):
            app.updateCommands(commands)

        case .setTitle(let title):
            app.title = title

        case .close:
            handleDisconnect(windowId: app.windowId)

        case .tapHandled:
            break
        }
    }

    func handleDisconnect(windowId: UInt64) {
        lock.lock()
        if let app = apps.removeValue(forKey: windowId) {
            app.stop()
        }
        lock.unlock()
        onAppDisconnected?(windowId)
    }

    /// Request all connected apps to render a frame.
    public func requestFrames() {
        lock.lock()
        let snapshot = Array(apps.values)
        lock.unlock()
        for app in snapshot {
            app.send(.requestFrame(width: app.width, height: app.height))
        }
    }

    public func sendResize(windowId: UInt64, width: Float, height: Float) {
        lock.lock()
        let app = apps[windowId]
        lock.unlock()
        app?.width = width
        app?.height = height
        app?.send(.resize(width: width, height: height))
    }

    public func sendPointerMove(windowId: UInt64, x: Float, y: Float) {
        lock.lock()
        let app = apps[windowId]
        lock.unlock()
        app?.send(.pointerMove(x: x, y: y))
    }

    public func sendPointerButton(windowId: UInt64, button: UInt32, pressed: Bool, x: Float, y: Float) {
        lock.lock()
        let app = apps[windowId]
        lock.unlock()
        app?.send(.pointerButton(button: button, pressed: pressed, x: x, y: y))
    }

    public func sendKey(windowId: UInt64, keycode: UInt32, pressed: Bool) {
        lock.lock()
        let app = apps[windowId]
        lock.unlock()
        app?.send(.key(keycode: keycode, pressed: pressed))
    }

    public func commands(for windowId: UInt64) -> [IPCRenderCommand] {
        lock.lock()
        let app = apps[windowId]
        lock.unlock()
        return app?.getCommands() ?? []
    }

    public func app(for windowId: UInt64) -> ConnectedApp? {
        lock.lock()
        defer { lock.unlock() }
        return apps[windowId]
    }

    public func stop() {
        acceptSource?.cancel()
        acceptSource = nil
        lock.lock()
        for (_, app) in apps { app.stop() }
        apps.removeAll()
        lock.unlock()
        if serverSocket >= 0 {
            Darwin.close(serverSocket)
            serverSocket = -1
        }
        unlink(socketPath)
    }

    deinit { stop() }
}

public enum CompositorError: Error {
    case socketFailed
    case bindFailed
    case listenFailed
}
