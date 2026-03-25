import Foundation
import PosixShim
import CloneProtocol

/// A client connected to launchservicesd.
final class LSDClient {
    let fd: Int32
    var readBuffer = Data()
    var readSource: DispatchSourceRead?

    weak var server: LaunchServicesServer?

    init(fd: Int32) { self.fd = fd }

    func startReading(on queue: DispatchQueue, server: LaunchServicesServer) {
        self.server = server
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.handleReadable() }
        source.setCancelHandler { [fd] in posix_close(fd) }
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
        while let (msg, consumed) = WireProtocol.decode(LSDRequest.self, from: readBuffer) {
            readBuffer = readBuffer.subdata(in: consumed..<readBuffer.count)
            server?.handle(message: msg, from: self)
        }
    }

    func send(_ message: LSDResponse) {
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

/// GCD-based Launch Services daemon.
/// Scans for .app bundles, builds an extension→app registry, serves queries.
public final class LaunchServicesServer {
    private var serverSocket: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private let ioQueue = DispatchQueue(label: "clone.lsd.io", attributes: .concurrent)
    private let lock = NSLock()

    private var clients: [Int32: LSDClient] = [:]
    private let socketPath: String
    private let initialScanDirs: [String]

    /// Registered apps, keyed by bundle identifier.
    private var apps: [String: AppRegistration] = [:]
    /// Extension → default bundle identifier.
    private var extensionMap: [String: String] = [:]

    public init(socketPath: String = launchservicesdSocketPath, scanDirectories: [String]? = nil) {
        self.socketPath = socketPath
        self.initialScanDirs = scanDirectories ?? [cloneApplicationsPath]
    }

    public func start() throws {
        unlink(socketPath)

        serverSocket = socket(AF_UNIX, CLONE_SOCK_STREAM, 0)
        guard serverSocket >= 0 else { throw LSDError.socketFailed }

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
            throw LSDError.bindFailed
        }

        guard posix_listen(serverSocket, 8) == 0 else {
            posix_close(serverSocket)
            throw LSDError.listenFailed
        }

        // Scan configured directories on startup
        scanDirectories(initialScanDirs)

        let source = DispatchSource.makeReadSource(fileDescriptor: serverSocket, queue: ioQueue)
        source.setEventHandler { [weak self] in self?.acceptNewConnections() }
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

            let client = LSDClient(fd: clientFd)
            lock.lock()
            clients[clientFd] = client
            lock.unlock()
            client.startReading(on: ioQueue, server: self)
        }
    }

    func handle(message: LSDRequest, from client: LSDClient) {
        lock.lock()
        defer { lock.unlock() }

        switch message {
        case .scan(let directories):
            scanDirectories(directories)
            client.send(.scanComplete(count: apps.count))

        case .defaultApp(let ext):
            let bundleId = extensionMap[ext.lowercased()]
            let reg = bundleId.flatMap { apps[$0] }
            client.send(.app(reg))

        case .appInfo(let bundleId):
            client.send(.app(apps[bundleId]))

        case .allApps:
            client.send(.apps(Array(apps.values)))

        case .register(let path):
            if let reg = parseBundle(at: path) {
                registerApp(reg)
                client.send(.app(reg))
            } else {
                client.send(.error("Failed to parse bundle at \(path)"))
            }
        }
    }

    func handleDisconnect(client: LSDClient) {
        lock.lock()
        clients.removeValue(forKey: client.fd)
        lock.unlock()
    }

    // MARK: - Scanning

    /// Scan directories for .app bundles (caller holds lock).
    private func scanDirectories(_ directories: [String]) {
        let fm = FileManager.default
        for dir in directories {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items where item.hasSuffix(".app") {
                let bundlePath = "\(dir)/\(item)"
                if let reg = parseBundle(at: bundlePath) {
                    registerApp(reg)
                }
            }
        }
    }

    /// Parse an .app bundle's Info.plist into an AppRegistration.
    private func parseBundle(at path: String) -> AppRegistration? {
        let plistPath = "\(path)/Contents/Info.plist"
        guard let data = FileManager.default.contents(atPath: plistPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }

        guard let bundleId = plist["CFBundleIdentifier"] as? String else { return nil }
        let bundleName = plist["CFBundleName"] as? String ?? ""
        let displayName = plist["CFBundleDisplayName"] as? String ?? bundleName
        let executableName = plist["CFBundleExecutable"] as? String ?? bundleName
        let executablePath = "\(path)/Contents/MacOS/\(executableName)"
        let iconFile = plist["CFBundleIconFile"] as? String
        let version = plist["CFBundleShortVersionString"] as? String

        var documentTypes: [DocumentTypeInfo] = []
        if let docTypes = plist["CFBundleDocumentTypes"] as? [[String: Any]] {
            for docType in docTypes {
                let name = docType["CFBundleTypeName"] as? String ?? ""
                let extensions = docType["CFBundleTypeExtensions"] as? [String] ?? []
                let utis = docType["LSItemContentTypes"] as? [String] ?? []
                let role = docType["CFBundleTypeRole"] as? String ?? "Viewer"
                documentTypes.append(DocumentTypeInfo(name: name, extensions: extensions, utis: utis, role: role))
            }
        }

        return AppRegistration(
            bundleIdentifier: bundleId,
            bundleName: bundleName,
            displayName: displayName,
            executablePath: executablePath,
            bundlePath: path,
            iconFile: iconFile,
            version: version,
            documentTypes: documentTypes
        )
    }

    /// Register an app and update the extension map (caller holds lock).
    private func registerApp(_ reg: AppRegistration) {
        apps[reg.bundleIdentifier] = reg
        for docType in reg.documentTypes {
            for ext in docType.extensions {
                // First registered app for an extension wins as default
                if extensionMap[ext.lowercased()] == nil {
                    extensionMap[ext.lowercased()] = reg.bundleIdentifier
                }
            }
        }
        fputs("launchservicesd: registered \(reg.bundleIdentifier) (\(reg.displayName))\n", stderr)
    }

    public func stop() {
        acceptSource?.cancel()
        acceptSource = nil
        lock.lock()
        for (_, client) in clients { client.stop() }
        clients.removeAll()
        lock.unlock()
        if serverSocket >= 0 {
            posix_close(serverSocket)
            serverSocket = -1
        }
        unlink(socketPath)
    }

    deinit { stop() }
}

public enum LSDError: Error {
    case socketFailed
    case bindFailed
    case listenFailed
}
