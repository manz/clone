import Foundation
import PosixShim
import CloneProtocol

/// A connected app process.
public final class ConnectedApp {
    public let windowId: UInt64
    public var appId: String
    public var title: String
    public var width: Float
    public var height: Float
    public var role: SurfaceRole = .window
    public var menus: [AppMenu] = []
    public private(set) var lastCommands: [IPCRenderCommand] = []

    /// Sheet surface state — nil means no sheet active.
    public var sheetSize: (width: Float, height: Float)?
    private var sheetCommands: [IPCRenderCommand] = []

    /// Shared memory surface state — non-nil when app uses app-side rendering.
    public var shmName: String?
    public var shmWidth: UInt32 = 0
    public var shmHeight: UInt32 = 0
    public var shmDirty: Bool = false

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
            posix_close(fd)
        }
        source.resume()
        readSource = source
    }

    private func handleReadable() {
        var buf = [UInt8](repeating: 0, count: 65536)
        let bytesRead = posix_read(fd, &buf, buf.count)
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

    public func send(_ message: CompositorMessage) {
        guard let data = try? WireProtocol.encode(message) else { return }
        data.withUnsafeBytes { ptr in
            _ = posix_write(fd, ptr.baseAddress!, data.count)
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

    public func updateSheetCommands(_ commands: [IPCRenderCommand]) {
        lock.lock()
        sheetCommands = commands
        lock.unlock()
    }

    public func getSheetCommands() -> [IPCRenderCommand] {
        lock.lock()
        defer { lock.unlock() }
        return sheetCommands
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

        serverSocket = socket(AF_UNIX, CLONE_SOCK_STREAM, 0)
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
                posix_bind(serverSocket, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            posix_close(serverSocket)
            throw CompositorError.bindFailed
        }

        guard posix_listen(serverSocket, 8) == 0 else {
            posix_close(serverSocket)
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
                    posix_accept(serverSocket, sockPtr, &addrLen)
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
    /// Callback when dock requests an app launch.
    public var onLaunchApp: ((String) -> Void)?
    /// Callback when dock requests restoring a minimized app.
    public var onRestoreApp: ((String) -> Void)?
    /// Callback when a menubar sends a menu action for the focused app.
    public var onMenuAction: ((String) -> Void)?
    /// Callback when an app requests an open-file dialog.
    public var onShowOpenPanel: ((UInt64, [String]) -> Void)?
    /// Callback when LoginWindow signals authentication succeeded.
    public var onSetColorScheme: ((Bool) -> Void)?
    public var onSessionReady: (() -> Void)?
    /// Callback when an app requests to open a file (NSWorkspace.open flow).
    public var onOpenFile: ((String) -> Void)?

    func handle(message: AppMessage, from app: ConnectedApp) {
        switch message {
        case .register(let appId, let title, let width, let height, let role):
            app.appId = appId
            app.title = title
            app.width = width
            app.height = height
            app.role = role
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

        case .launchApp(let appId):
            onLaunchApp?(appId)

        case .restoreApp(let appId):
            onRestoreApp?(appId)

        case .registerMenus(let menus):
            app.menus = menus

        case .menuAction(let itemId):
            onMenuAction?(itemId)

        case .showOpenPanel(let allowedTypes):
            onShowOpenPanel?(app.windowId, allowedTypes)

        case .setColorScheme(let dark):
            onSetColorScheme?(dark)

        case .sessionReady:
            onSessionReady?()

        case .showSheet(let width, let height):
            app.sheetSize = (width: width, height: height)
            app.updateSheetCommands([])

        case .sheetFrame(let commands):
            app.updateSheetCommands(commands)

        case .dismissSheet:
            app.sheetSize = nil
            app.updateSheetCommands([])

        case .openFile(let path):
            onOpenFile?(path)

        case .avocadoEvent(let targetAppId, let event):
            routeAvocadoEvent(targetAppId: targetAppId, event: event)

        case .surfaceCreated(let shmName, let width, let height):
            app.shmName = shmName
            app.shmWidth = width
            app.shmHeight = height
            app.send(.surfaceReady(surfaceId: app.windowId))

        case .surfaceUpdated:
            app.shmDirty = true

        case .surfaceResized(let width, let height):
            app.shmWidth = width
            app.shmHeight = height
        }
    }

    /// Route an AvocadoEvent to a connected app by bundle identifier.
    func routeAvocadoEvent(targetAppId: String, event: AvocadoEvent) {
        lock.lock()
        let targets = apps.values.filter { $0.appId == targetAppId }
        lock.unlock()
        for app in targets {
            app.send(.avocadoEvent(event))
        }
        if targets.isEmpty {
            fputs("[compositor] AvocadoEvent: no connected app with id \(targetAppId)\n", stderr)
        }
    }

    public func handleDisconnect(windowId: UInt64) {
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
            if app.role == .service { continue }
            app.send(.requestFrame(width: app.width, height: app.height))
            if let sheet = app.sheetSize {
                app.send(.requestSheetFrame(width: sheet.width, height: sheet.height))
            }
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

    /// Update the app's dimensions without sending a resize message.
    /// Used during live resize so requestFrames() picks up the new size.
    public func updateAppDimensions(windowId: UInt64, width: Float, height: Float) {
        lock.lock()
        let app = apps[windowId]
        lock.unlock()
        app?.width = width
        app?.height = height
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

    public func sendKeyChar(windowId: UInt64, character: String) {
        lock.lock()
        let app = apps[windowId]
        lock.unlock()
        app?.send(.keyChar(character: character))
    }

    public func sendScroll(windowId: UInt64, deltaX: Float, deltaY: Float) {
        lock.lock()
        let app = apps[windowId]
        lock.unlock()
        app?.send(.scroll(deltaX: deltaX, deltaY: deltaY))
    }

    public func sendWindowClosed(windowId: UInt64) {
        lock.lock()
        let app = apps[windowId]
        lock.unlock()
        app?.send(.windowClosed)
    }

    public func sendTerminate(windowId: UInt64) {
        lock.lock()
        let app = apps[windowId]
        lock.unlock()
        app?.send(.terminate)
    }

    public func sendMenuAction(windowId: UInt64, itemId: String) {
        lock.lock()
        let app = apps[windowId]
        lock.unlock()
        app?.send(.menuAction(itemId: itemId))
    }

    public func sendOpenPanelResult(windowId: UInt64, path: String?) {
        lock.lock()
        let app = apps[windowId]
        lock.unlock()
        app?.send(.openPanelResult(path: path))
    }

    /// Get menus for a given app window ID.
    public func menus(for windowId: UInt64) -> [AppMenu] {
        lock.lock()
        let app = apps[windowId]
        lock.unlock()
        return app?.menus ?? []
    }

    public func sheetSize(for windowId: UInt64) -> (width: Float, height: Float)? {
        lock.lock()
        let app = apps[windowId]
        lock.unlock()
        return app?.sheetSize
    }

    public func sheetCommands(for windowId: UInt64) -> [IPCRenderCommand] {
        lock.lock()
        let app = apps[windowId]
        lock.unlock()
        return app?.getSheetCommands() ?? []
    }

    public func sendSheetBackdropTapped(windowId: UInt64) {
        lock.lock()
        let app = apps[windowId]
        lock.unlock()
        app?.send(.sheetBackdropTapped)
    }

    public func sendSheetPointerButton(windowId: UInt64, button: UInt32, pressed: Bool, x: Float, y: Float) {
        lock.lock()
        let app = apps[windowId]
        lock.unlock()
        app?.send(.sheetPointerButton(button: button, pressed: pressed, x: x, y: y))
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
            posix_close(serverSocket)
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
