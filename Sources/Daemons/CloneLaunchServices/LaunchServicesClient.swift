import Foundation
import PosixShim
import CloneProtocol

/// Synchronous client for querying launchservicesd.
public final class LaunchServicesClient: @unchecked Sendable {
    private var fd: Int32 = -1
    private var readBuffer = Data()
    private let socketPath: String

    public init(socketPath: String = launchservicesdSocketPath) {
        self.socketPath = socketPath
    }

    public func connect() throws {
        fd = socket(AF_UNIX, CLONE_SOCK_STREAM, 0)
        guard fd >= 0 else { throw LSDError.socketFailed }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) { pathPtr in
                pathPtr.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
                    _ = strlcpy(dest, ptr, 104)
                }
            }
        }

        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                posix_connect(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else {
            posix_close(fd)
            fd = -1
            throw LSDError.socketFailed
        }
    }

    public func disconnect() {
        if fd >= 0 {
            posix_close(fd)
            fd = -1
        }
    }

    deinit { disconnect() }

    // MARK: - Public API

    public func defaultApp(forExtension ext: String) -> AppRegistration? {
        guard let response = sendRequest(.defaultApp(forExtension: ext)) else { return nil }
        if case .app(let reg) = response { return reg }
        return nil
    }

    public func appInfo(bundleIdentifier: String) -> AppRegistration? {
        guard let response = sendRequest(.appInfo(bundleIdentifier: bundleIdentifier)) else { return nil }
        if case .app(let reg) = response { return reg }
        return nil
    }

    public func allApps() -> [AppRegistration] {
        guard let response = sendRequest(.allApps) else { return [] }
        if case .apps(let list) = response { return list }
        return []
    }

    public func scan(directories: [String]) {
        _ = sendRequest(.scan(directories: directories))
    }

    /// Launch an app by bundle identifier. Returns the registration if launched.
    public func launch(bundleIdentifier: String) -> AppRegistration? {
        guard let response = sendRequest(.launch(bundleIdentifier: bundleIdentifier)) else { return nil }
        if case .launched(let reg) = response { return reg }
        return nil
    }

    /// Launch an .app bundle at a given path. Registers it first if not known.
    public func launchBundle(path: String) -> AppRegistration? {
        guard let response = sendRequest(.launchBundle(path: path)) else { return nil }
        if case .launched(let reg) = response { return reg }
        return nil
    }

    /// Open a file with its default app (or a specific app).
    public func openFile(path: String, withApp: String? = nil) -> AppRegistration? {
        guard let response = sendRequest(.openFile(path: path, withApp: withApp)) else { return nil }
        if case .launched(let reg) = response { return reg }
        return nil
    }

    // MARK: - Wire

    private func sendRequest(_ request: LSDRequest) -> LSDResponse? {
        guard fd >= 0 else { return nil }
        guard let data = try? WireProtocol.encode(request) else { return nil }
        data.withUnsafeBytes { ptr in
            _ = posix_write(fd, ptr.baseAddress!, data.count)
        }
        return readResponse()
    }

    private func readResponse() -> LSDResponse? {
        var buf = [UInt8](repeating: 0, count: 65536)
        // Blocking read with timeout
        while true {
            let bytesRead = posix_read(fd, &buf, buf.count)
            guard bytesRead > 0 else { return nil }
            readBuffer.append(contentsOf: buf[0..<bytesRead])
            if let (msg, consumed) = WireProtocol.decode(LSDResponse.self, from: readBuffer) {
                readBuffer = readBuffer.subdata(in: consumed..<readBuffer.count)
                return msg
            }
        }
    }
}
