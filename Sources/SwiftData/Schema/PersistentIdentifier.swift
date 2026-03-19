import Foundation

/// UUID-based stable identity for persistent models.
public struct PersistentIdentifier: Hashable, Codable, CustomStringConvertible {
    public let id: UUID

    public init() {
        self.id = UUID()
    }

    public init(id: UUID) {
        self.id = id
    }

    public init?(uuidString: String) {
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        self.id = uuid
    }

    public var description: String { id.uuidString }
}
