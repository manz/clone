import Foundation
import PosixShim
import CloneProtocol

/// A connected client (app or service).
final class AEClient {
    let fd: Int32
    var appId: String?
    var readBuffer = Data()
    var readSource: DispatchSourceRead?
    weak var server: AvocadoEventsServer?

    init(fd: Int32) { self.fd = fd }

    func startReading(on queue: DispatchQueue, server: AvocadoEventsServer) {
        self.server = server
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.handleReadable() }
        source.setCancelHandler { [fd] in posix_close(fd) }
        source.resume()
        readSource = source
    }

    func stop() { readSource?.cancel() }

    func send(_ response: AEResponse) {
        guard let data = try? WireProtocol.encode(response) else { return }
        data.withUnsafeBytes { ptr in
            _ = posix_write(fd, ptr.baseAddress!, data.count)
        }
    }

    private func handleReadable() {
        var buf = [UInt8](repeating: 0, count: 65536)
        let bytesRead = posix_read(fd, &buf, buf.count)
        guard bytesRead > 0 else {
            server?.handleDisconnect(client: self)
            return
        }
        readBuffer.append(contentsOf: buf[0..<bytesRead])
        while let (msg, consumed) = WireProtocol.decode(AERequest.self, from: readBuffer) {
            readBuffer = readBuffer.subdata(in: consumed..<readBuffer.count)
            server?.handle(message: msg, from: self)
        }
    }
}

/// The AvocadoEvents daemon — routes typed events between processes.
public final class AvocadoEventsServer {
    private var serverSocket: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private let ioQueue = DispatchQueue(label: "clone.avocadoevents.io", attributes: .concurrent)
    private let lock = NSLock()

    private var clients: [Int32: AEClient] = [:]
    /// Apps registered by appId → list of client fds (multiple windows per app possible).
    private var appClients: [String: [Int32]] = [:]
    /// Buffered events for apps that haven't connected yet.
    private var pendingEvents: [String: [AvocadoEvent]] = [:]
    private let socketPath: String

    public init(socketPath: String = avocadoeventsdSocketPath) {
        self.socketPath = socketPath
    }

    public func start() throws {
        unlink(socketPath)

        serverSocket = socket(AF_UNIX, CLONE_SOCK_STREAM, 0)
        guard serverSocket >= 0 else { throw AEError.socketFailed }

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
            throw AEError.bindFailed
        }

        guard posix_listen(serverSocket, 32) == 0 else {
            posix_close(serverSocket)
            throw AEError.listenFailed
        }

        let source = DispatchSource.makeReadSource(fileDescriptor: serverSocket, queue: ioQueue)
        source.setEventHandler { [weak self] in self?.acceptNewConnections() }
        source.resume()
        acceptSource = source
    }

    private func acceptNewConnections() {
        let clientFd = posix_accept(serverSocket, nil, nil)
        guard clientFd >= 0 else { return }

        let client = AEClient(fd: clientFd)
        lock.lock()
        clients[clientFd] = client
        lock.unlock()

        client.startReading(on: ioQueue, server: self)
    }

    func handle(message: AERequest, from client: AEClient) {
        switch message {
        case .register(let appId):
            lock.lock()
            client.appId = appId
            appClients[appId, default: []].append(client.fd)
            // Flush any buffered events for this appId
            let buffered = pendingEvents.removeValue(forKey: appId) ?? []
            lock.unlock()
            client.send(.ok)
            for event in buffered {
                client.send(.event(event))
                logErr("[avocadoeventsd] Delivered buffered event to \(appId)\n")
            }
            logErr("[avocadoeventsd] Registered \(appId)\n")

        case .send(let targetAppId, let event):
            lock.lock()
            let targetFds = appClients[targetAppId] ?? []
            let targets = targetFds.compactMap { clients[$0] }
            if targets.isEmpty {
                // Buffer for when the app connects
                pendingEvents[targetAppId, default: []].append(event)
                lock.unlock()
                logErr("[avocadoeventsd] Buffered event for \(targetAppId) (not yet connected)\n")
                client.send(.ok)
            } else {
                lock.unlock()
                for target in targets {
                    target.send(.event(event))
                }
                client.send(.ok)
            }

        case .isRegistered(let appId):
            lock.lock()
            let registered = !(appClients[appId] ?? []).isEmpty
            lock.unlock()
            client.send(.registered(registered))
        }
    }

    func handleDisconnect(client: AEClient) {
        lock.lock()
        clients.removeValue(forKey: client.fd)
        if let appId = client.appId {
            appClients[appId]?.removeAll(where: { $0 == client.fd })
            if appClients[appId]?.isEmpty == true {
                appClients.removeValue(forKey: appId)
            }
        }
        lock.unlock()
        client.stop()
    }
}

enum AEError: Error {
    case socketFailed, bindFailed, listenFailed
}
