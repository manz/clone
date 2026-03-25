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

    /// Get the closure for a tap ID (for capturing in long-lived registries like menus).
    public func handler(for id: UInt64) -> (() -> Void)? {
        handlers[id]
    }

    /// Number of registered handlers.
    public var count: Int { handlers.count }

    /// Reset counter so the same call sequence produces the same IDs.
    /// Handlers survive — new registrations overwrite at the same IDs.
    public func resetCounter() {
        nextId = 1
    }

    /// Full reset (for tests).
    public func clear() {
        handlers.removeAll()
        nextId = 1
    }
}
