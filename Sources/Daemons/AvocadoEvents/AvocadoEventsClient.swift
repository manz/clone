import Foundation
import PosixShim
import CloneProtocol

/// Client for connecting to avocadoeventsd.
///
/// Apps call `connect()` + `register()` at startup, then `listen()` to receive events.
/// Services call `connect()` + `send()` to route events to apps.
public final class AvocadoEventsClient: @unchecked Sendable {
    private var fd: Int32 = -1
    private var readBuffer = Data()
    private let socketPath: String

    /// Callback for received events (called on the listener thread).
    public var onEvent: ((AvocadoEvent) -> Void)?

    public init(socketPath: String = avocadoeventsdSocketPath) {
        self.socketPath = socketPath
    }

    public func connect() throws {
        fd = socket(AF_UNIX, CLONE_SOCK_STREAM, 0)
        guard fd >= 0 else { throw AEClientError.connectionFailed }

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
            throw AEClientError.connectionFailed
        }
    }

    public func disconnect() {
        if fd >= 0 { posix_close(fd); fd = -1 }
    }

    deinit { disconnect() }

    /// Register this connection with an appId so events can be delivered to it.
    /// Waits for acknowledgement before returning.
    public func register(appId: String) {
        sendRequest(.register(appId: appId))
        _ = readOneResponse()
    }

    /// Send an event to a target app. Waits for acknowledgement.
    public func send(to targetAppId: String, event: AvocadoEvent) {
        sendRequest(.send(targetAppId: targetAppId, event: event))
        _ = readOneResponse()
    }

    /// Blocking read loop — call on a background thread. Dispatches events to `onEvent`.
    public func listen() {
        var buf = [UInt8](repeating: 0, count: 65536)
        while fd >= 0 {
            let bytesRead = posix_read(fd, &buf, buf.count)
            guard bytesRead > 0 else { break }
            readBuffer.append(contentsOf: buf[0..<bytesRead])
            while let (msg, consumed) = WireProtocol.decode(AEResponse.self, from: readBuffer) {
                readBuffer = readBuffer.subdata(in: consumed..<readBuffer.count)
                if case .event(let event) = msg {
                    onEvent?(event)
                }
            }
        }
    }

    /// Blocking read of a single response.
    private func readOneResponse() -> AEResponse? {
        var buf = [UInt8](repeating: 0, count: 65536)
        while fd >= 0 {
            let bytesRead = posix_read(fd, &buf, buf.count)
            guard bytesRead > 0 else { return nil }
            readBuffer.append(contentsOf: buf[0..<bytesRead])
            if let (msg, consumed) = WireProtocol.decode(AEResponse.self, from: readBuffer) {
                readBuffer = readBuffer.subdata(in: consumed..<readBuffer.count)
                return msg
            }
        }
        return nil
    }

    private func sendRequest(_ request: AERequest) {
        guard fd >= 0 else { return }
        guard let data = try? WireProtocol.encode(request) else { return }
        data.withUnsafeBytes { ptr in
            _ = posix_write(fd, ptr.baseAddress!, data.count)
        }
    }
}

enum AEClientError: Error {
    case connectionFailed
}
