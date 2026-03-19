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

    let fileHandle: FileHandle
    var readBuffer = Data()

    init(windowId: UInt64, appId: String, title: String, width: Float, height: Float, fileHandle: FileHandle) {
        self.windowId = windowId
        self.appId = appId
        self.title = title
        self.width = width
        self.height = height
        self.fileHandle = fileHandle
    }

    func send(_ message: CompositorMessage) {
        guard let data = try? WireProtocol.encode(message) else { return }
        try? fileHandle.write(contentsOf: data)
    }

    func processIncoming() -> [AppMessage] {
        guard let available = try? fileHandle.availableData, !available.isEmpty else {
            return []
        }
        readBuffer.append(available)

        var messages: [AppMessage] = []
        while let (msg, consumed) = WireProtocol.decode(AppMessage.self, from: readBuffer) {
            messages.append(msg)
            readBuffer = readBuffer.subdata(in: consumed..<readBuffer.count)
        }
        return messages
    }

    public func updateCommands(_ commands: [IPCRenderCommand]) {
        lastCommands = commands
    }
}

/// The compositor's IPC server. Listens on a Unix domain socket for app connections.
public final class CompositorServer {
    private var serverSocket: Int32 = -1
    private var apps: [UInt64: ConnectedApp] = [:]
    private var clientSockets: [Int32: UInt64] = [:] // fd → windowId
    private var nextWindowId: UInt64 = 1
    private let socketPath: String

    public var connectedApps: [ConnectedApp] {
        Array(apps.values)
    }

    public init(socketPath: String = compositorSocketPath) {
        self.socketPath = socketPath
    }

    /// Start listening. Non-blocking.
    public func start() throws {
        // Remove stale socket
        unlink(socketPath)

        serverSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            throw CompositorError.socketFailed
        }

        // Set non-blocking
        let flags = fcntl(serverSocket, F_GETFL)
        fcntl(serverSocket, F_SETFL, flags | O_NONBLOCK)

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) { pathPtr in
                let bound = pathPtr.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
                    strlcpy(dest, ptr, 104)
                }
                _ = bound
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
    }

    /// Poll for new connections and incoming messages. Call each frame.
    public func poll() {
        acceptNewConnections()
        processMessages()
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

            // Set non-blocking
            let flags = fcntl(clientFd, F_GETFL)
            fcntl(clientFd, F_SETFL, flags | O_NONBLOCK)

            // Read the register message synchronously (first message must be register)
            // We'll handle it in processMessages on next poll
            let handle = FileHandle(fileDescriptor: clientFd, closeOnDealloc: true)

            // Temporarily store — will be promoted to ConnectedApp on Register
            let tempId = nextWindowId
            nextWindowId += 1
            let app = ConnectedApp(
                windowId: tempId, appId: "pending", title: "Loading...",
                width: 600, height: 400, fileHandle: handle
            )
            apps[tempId] = app
            clientSockets[clientFd] = tempId
        }
    }

    private func processMessages() {
        for (_, app) in apps {
            let messages = app.processIncoming()
            for msg in messages {
                handle(message: msg, from: app)
            }
        }
    }

    private func handle(message: AppMessage, from app: ConnectedApp) {
        switch message {
        case .register(let appId, let title, let width, let height):
            app.appId = appId
            app.title = title
            app.width = width
            app.height = height
            app.send(.windowCreated(windowId: app.windowId, width: width, height: height))

        case .frame(let commands):
            app.updateCommands(commands)

        case .setTitle(let title):
            app.title = title

        case .close:
            apps.removeValue(forKey: app.windowId)

        case .tapHandled:
            break
        }
    }

    /// Request all connected apps to render a frame.
    public func requestFrames() {
        for (_, app) in apps {
            app.send(.requestFrame(width: app.width, height: app.height))
        }
    }

    /// Send input to a specific app.
    public func sendPointerMove(windowId: UInt64, x: Float, y: Float) {
        apps[windowId]?.send(.pointerMove(x: x, y: y))
    }

    public func sendPointerButton(windowId: UInt64, button: UInt32, pressed: Bool, x: Float, y: Float) {
        apps[windowId]?.send(.pointerButton(button: button, pressed: pressed, x: x, y: y))
    }

    public func sendKey(windowId: UInt64, keycode: UInt32, pressed: Bool) {
        apps[windowId]?.send(.key(keycode: keycode, pressed: pressed))
    }

    /// Get the last render commands from an app.
    public func commands(for windowId: UInt64) -> [IPCRenderCommand] {
        apps[windowId]?.lastCommands ?? []
    }

    public func app(for windowId: UInt64) -> ConnectedApp? {
        apps[windowId]
    }

    public func stop() {
        if serverSocket >= 0 {
            Darwin.close(serverSocket)
            serverSocket = -1
        }
        unlink(socketPath)
    }

    deinit {
        stop()
    }
}

public enum CompositorError: Error {
    case socketFailed
    case bindFailed
    case listenFailed
}
