import Foundation

/// Registry for onTap handlers. Maps tap IDs to closures.
public final class TapRegistry: @unchecked Sendable {
    public static let shared = TapRegistry()

    private var handlers: [UInt64: () -> Void] = [:]
    private var nextId: UInt64 = 1

    private init() {}

    /// Register a tap handler and return its ID.
    public func register(_ handler: @escaping () -> Void) -> UInt64 {
        let id = nextId
        nextId += 1
        handlers[id] = handler
        return id
    }

    /// Fire a tap handler by ID.
    public func fire(id: UInt64) {
        handlers[id]?()
    }

    /// Number of registered handlers.
    public var count: Int { handlers.count }

    /// Clear all handlers (call between frames).
    public func clear() {
        handlers.removeAll()
        nextId = 1
    }
}
