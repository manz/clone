import Foundation
import PosixShim
import CloneProtocol

/// Role of a connected daemon client.
enum DaemonClientRole {
    case publisher   // Music app that publishes now-playing info
    case observer    // MenuBar that observes now-playing changes
    case unknown
}

/// A client connected to the daemon.
final class ConnectedDaemonClient {
    let fd: Int32
    var readBuffer = Data()
    var readSource: DispatchSourceRead?
    var role: DaemonClientRole = .unknown

    weak var server: DaemonServer?

    init(fd: Int32) {
        self.fd = fd
    }

    func startReading(on queue: DispatchQueue, server: DaemonServer) {
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
            readSource?.cancel()
            readSource = nil
            server?.handleDisconnect(client: self)
            return
        }

        readBuffer.append(contentsOf: buf[0..<bytesRead])

        while let (msg, consumed) = WireProtocol.decode(DaemonRequest.self, from: readBuffer) {
            readBuffer = readBuffer.subdata(in: consumed..<readBuffer.count)
            server?.handle(message: msg, from: self)
        }
    }

    func send(_ message: DaemonResponse) {
        guard let data = try? WireProtocol.encode(message) else { return }
        data.withUnsafeBytes { ptr in
            _ = posix_write(fd, ptr.baseAddress!, data.count)
        }
    }

    func stop() {
        readSource?.cancel()
        readSource = nil
    }
}

/// GCD-based socket server for the now-playing daemon.
public final class DaemonServer {
    private var serverSocket: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private let ioQueue = DispatchQueue(label: "clone.daemon.io", attributes: .concurrent)
    private let lock = NSLock()

    private var clients: [Int32: ConnectedDaemonClient] = [:]
    private var publisher: ConnectedDaemonClient?
    private var observers: [ConnectedDaemonClient] = []
    private var currentNowPlaying: NowPlayingInfo?
    private let socketPath: String

    public init(socketPath: String = daemonSocketPath) {
        self.socketPath = socketPath
    }

    public func start() throws {
        unlink(socketPath)

        serverSocket = socket(AF_UNIX, CLONE_SOCK_STREAM, 0)
        guard serverSocket >= 0 else { throw DaemonError.socketFailed }

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
            throw DaemonError.bindFailed
        }

        guard posix_listen(serverSocket, 8) == 0 else {
            posix_close(serverSocket)
            throw DaemonError.listenFailed
        }

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

            let client = ConnectedDaemonClient(fd: clientFd)

            lock.lock()
            clients[clientFd] = client
            lock.unlock()

            client.startReading(on: ioQueue, server: self)
        }
    }

    func handle(message: DaemonRequest, from client: ConnectedDaemonClient) {
        lock.lock()
        defer { lock.unlock() }

        switch message {
        case .publishNowPlaying(let info):
            client.role = .publisher
            publisher = client
            currentNowPlaying = info
            for observer in observers {
                observer.send(.nowPlayingChanged(info))
            }

        case .clearNowPlaying:
            currentNowPlaying = nil
            if publisher?.fd == client.fd {
                publisher = nil
            }
            for observer in observers {
                observer.send(.nowPlayingChanged(nil))
            }

        case .remoteCommand(let command):
            // Forward to publisher
            publisher?.send(.remoteCommand(command))

        case .observe:
            client.role = .observer
            if !observers.contains(where: { $0.fd == client.fd }) {
                observers.append(client)
            }
            // Send current state immediately
            client.send(.nowPlayingChanged(currentNowPlaying))
        }
    }

    func handleDisconnect(client: ConnectedDaemonClient) {
        lock.lock()
        clients.removeValue(forKey: client.fd)
        observers.removeAll(where: { $0.fd == client.fd })

        // If publisher disconnected, clear now-playing and notify observers
        if publisher?.fd == client.fd {
            publisher = nil
            currentNowPlaying = nil
            for observer in observers {
                observer.send(.nowPlayingChanged(nil))
            }
        }
        lock.unlock()
    }

    public func stop() {
        acceptSource?.cancel()
        acceptSource = nil
        lock.lock()
        for (_, client) in clients { client.stop() }
        clients.removeAll()
        observers.removeAll()
        publisher = nil
        lock.unlock()
        if serverSocket >= 0 {
            posix_close(serverSocket)
            serverSocket = -1
        }
        unlink(socketPath)
    }

    deinit { stop() }
}

public enum DaemonError: Error {
    case socketFailed
    case bindFailed
    case listenFailed
}
