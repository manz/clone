import Foundation
import PosixShim

// MARK: - Internal IPC types (mirrors CloneProtocol keychain types)
// Security can't import CloneProtocol because Foundation imports the system
// Security framework, creating a circular dependency. These types are wire-
// compatible with CloneProtocol's keychain types (same JSON encoding).

let keychainSocketPath: String = {
    let base = ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"] ?? "/tmp"
    return "\(base)/clone-keychain.sock"
}()

enum SecItemClass: String, Codable, Sendable {
    case internetPassword, genericPassword, certificate, key, identity
}

struct KeychainItem: Codable, Sendable, Equatable {
    var itemClass: SecItemClass
    var service: String?
    var account: String?
    var server: String?
    var label: String?
    var valueData: Data?
    var accessGroup: String?
    var appId: String
    var creationDate: Date
    var modificationDate: Date

    init(
        itemClass: SecItemClass, service: String? = nil, account: String? = nil,
        server: String? = nil, label: String? = nil, valueData: Data? = nil,
        accessGroup: String? = nil, appId: String,
        creationDate: Date = Date(), modificationDate: Date = Date()
    ) {
        self.itemClass = itemClass; self.service = service; self.account = account
        self.server = server; self.label = label; self.valueData = valueData
        self.accessGroup = accessGroup; self.appId = appId
        self.creationDate = creationDate; self.modificationDate = modificationDate
    }
}

struct KeychainSearchQuery: Codable, Sendable {
    var itemClass: SecItemClass?
    var service: String?
    var account: String?
    var server: String?
    var matchLimit: MatchLimit
    var returnData: Bool

    enum MatchLimit: String, Codable, Sendable { case one, all }

    init(
        itemClass: SecItemClass? = nil, service: String? = nil, account: String? = nil,
        server: String? = nil, matchLimit: MatchLimit = .one, returnData: Bool = true
    ) {
        self.itemClass = itemClass; self.service = service; self.account = account
        self.server = server; self.matchLimit = matchLimit; self.returnData = returnData
    }
}

enum KeychainRequest: Codable, Sendable {
    case add(KeychainItem)
    case search(KeychainSearchQuery)
    case update(query: KeychainSearchQuery, attributes: KeychainItem)
    case delete(KeychainSearchQuery)
}

enum KeychainResponse: Codable, Sendable {
    case success
    case item(KeychainItem)
    case items([KeychainItem])
    case error(KeychainErrorCode)
}

enum KeychainErrorCode: Int32, Codable, Sendable {
    case success = 0
    case itemNotFound = -25300
    case duplicateItem = -25299
    case authFailed = -25293
    case interactionNotAllowed = -25308
    case decode = -26275
    case param = -50
    case unimplemented = -4
}

// MARK: - Wire protocol (4-byte length prefix + JSON, same as CloneProtocol)

private enum Wire {
    static func encode<T: Encodable>(_ message: T) throws -> Data {
        let json = try JSONEncoder().encode(message)
        var length = UInt32(json.count).bigEndian
        var data = Data(bytes: &length, count: 4)
        data.append(json)
        return data
    }

    static func decode<T: Decodable>(_ type: T.Type, from buffer: Data) -> (T, Int)? {
        guard buffer.count >= 4 else { return nil }
        let length = buffer.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        let totalLength = 4 + Int(length)
        guard buffer.count >= totalLength else { return nil }
        let jsonData = buffer.subdata(in: 4..<totalLength)
        guard let message = try? JSONDecoder().decode(T.self, from: jsonData) else { return nil }
        return (message, totalLength)
    }
}

// MARK: - Keychain IPC client

/// Protocol for keychain IPC (enables testing with mock).
protocol KeychainClientProtocol {
    func send(_ request: KeychainRequest) -> KeychainResponse
}

/// IPC client to the keychaind daemon.
final class KeychainClient: KeychainClientProtocol, @unchecked Sendable {
    private var socketFd: Int32 = -1
    private let lock = NSLock()
    private(set) var isConnected = false

    func connect() -> Bool {
        socketFd = socket(AF_UNIX, CLONE_SOCK_STREAM, 0)
        guard socketFd >= 0 else { return false }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        keychainSocketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) { pathPtr in
                pathPtr.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
                    _ = strlcpy(dest, ptr, 104)
                }
            }
        }

        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                posix_connect(socketFd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else {
            posix_close(socketFd)
            socketFd = -1
            return false
        }
        isConnected = true
        return true
    }

    func send(_ request: KeychainRequest) -> KeychainResponse {
        guard isConnected || connect() else { return .error(.itemNotFound) }

        guard let data = try? Wire.encode(request) else { return .error(.param) }
        data.withUnsafeBytes { ptr in
            _ = posix_write(socketFd, ptr.baseAddress!, data.count)
        }

        var buffer = Data()
        var buf = [UInt8](repeating: 0, count: 65536)
        while true {
            let n = posix_read(socketFd, &buf, buf.count)
            guard n > 0 else { return .error(.itemNotFound) }
            buffer.append(contentsOf: buf[0..<n])
            if let (response, _) = Wire.decode(KeychainResponse.self, from: buffer) {
                return response
            }
        }
    }

    func disconnect() {
        if socketFd >= 0 {
            posix_close(socketFd)
            socketFd = -1
        }
        isConnected = false
    }
}
