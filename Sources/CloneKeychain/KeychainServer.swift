import Foundation
import CloneProtocol

/// A client connected to the keychain daemon.
final class ConnectedKeychainClient {
    let fd: Int32
    var readBuffer = Data()
    var readSource: DispatchSourceRead?
    weak var server: KeychainServer?

    init(fd: Int32) {
        self.fd = fd
    }

    func startReading(on queue: DispatchQueue, server: KeychainServer) {
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
            readSource?.cancel()
            readSource = nil
            server?.handleDisconnect(client: self)
            return
        }

        readBuffer.append(contentsOf: buf[0..<bytesRead])

        while let (msg, consumed) = WireProtocol.decode(KeychainRequest.self, from: readBuffer) {
            readBuffer = readBuffer.subdata(in: consumed..<readBuffer.count)
            server?.handle(message: msg, from: self)
        }
    }

    func send(_ message: KeychainResponse) {
        guard let data = try? WireProtocol.encode(message) else { return }
        data.withUnsafeBytes { ptr in
            _ = Darwin.write(fd, ptr.baseAddress!, data.count)
        }
    }

    func stop() {
        readSource?.cancel()
        readSource = nil
    }
}

/// GCD-based socket server for the keychain daemon.
public final class KeychainServer {
    private var serverSocket: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private let ioQueue = DispatchQueue(label: "clone.keychain.io", attributes: .concurrent)
    private let lock = NSLock()
    private var clients: [Int32: ConnectedKeychainClient] = [:]
    private let store: KeychainStoreProtocol
    private let socketPath: String

    public init(store: KeychainStoreProtocol? = nil, socketPath: String = keychainSocketPath) {
        self.store = store ?? KeychainStore()
        self.socketPath = socketPath
    }

    public func start() throws {
        unlink(socketPath)

        serverSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverSocket >= 0 else { throw KeychainServerError.socketFailed }

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
            throw KeychainServerError.bindFailed
        }

        guard listen(serverSocket, 8) == 0 else {
            Darwin.close(serverSocket)
            throw KeychainServerError.listenFailed
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
                    accept(serverSocket, sockPtr, &addrLen)
                }
            }
            guard clientFd >= 0 else { break }

            let flags = fcntl(clientFd, F_GETFL)
            _ = fcntl(clientFd, F_SETFL, flags | O_NONBLOCK)

            let client = ConnectedKeychainClient(fd: clientFd)

            lock.lock()
            clients[clientFd] = client
            lock.unlock()

            client.startReading(on: ioQueue, server: self)
        }
    }

    func handle(message: KeychainRequest, from client: ConnectedKeychainClient) {
        switch message {
        case .add(let item):
            let code = store.add(item)
            client.send(code == .success ? .success : .error(code))

        case .search(let query):
            client.send(store.search(query))

        case .update(let query, let attributes):
            let code = store.update(query: query, attributes: attributes)
            client.send(code == .success ? .success : .error(code))

        case .delete(let query):
            let code = store.delete(query)
            client.send(code == .success ? .success : .error(code))
        }
    }

    func handleDisconnect(client: ConnectedKeychainClient) {
        lock.lock()
        clients.removeValue(forKey: client.fd)
        lock.unlock()
    }

    public func stop() {
        acceptSource?.cancel()
        acceptSource = nil
        lock.lock()
        for (_, client) in clients { client.stop() }
        clients.removeAll()
        lock.unlock()
        if serverSocket >= 0 {
            Darwin.close(serverSocket)
            serverSocket = -1
        }
        unlink(socketPath)
    }

    deinit { stop() }
}

public enum KeychainServerError: Error {
    case socketFailed
    case bindFailed
    case listenFailed
}
