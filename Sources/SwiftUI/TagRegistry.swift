import Foundation

/// Registry for .tag() values attached to views.
/// Used by List(selection:) to map tapped rows to selection values.
public final class TagRegistry: @unchecked Sendable {
    public static let shared = TagRegistry()

    private var tags: [UInt64: AnyHashable] = [:]
    private var nextId: UInt64 = 1

    private init() {}

    /// Register a tag value and get a unique ID.
    public func register<V: Hashable>(_ value: V) -> UInt64 {
        let id = nextId
        nextId += 1
        tags[id] = AnyHashable(value)
        return id
    }

    /// Get the tag value for an ID.
    public func value(for id: UInt64) -> AnyHashable? {
        tags[id]
    }

    /// Persisted selection values (survives across frame rebuilds)
    private var selections: [String: AnyHashable] = [:]

    /// Store a selection value for a key (the binding's identity)
    public func setSelection(_ value: AnyHashable, forKey key: String) {
        selections[key] = value
    }

    /// Get persisted selection for a key
    public func getSelection(forKey key: String) -> AnyHashable? {
        selections[key]
    }

    /// Clear all tags (called each frame). Selections persist.
    public func clear() {
        tags.removeAll()
        nextId = 1
    }
}
