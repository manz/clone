import Foundation

/// Tracks previous values for `.onChange(of:)` modifiers.
/// Keyed by source location (#fileID:#line) for stability across view tree shape changes.
public final class OnChangeRegistry: @unchecked Sendable {
    public static let shared = OnChangeRegistry()

    private var values: [String: Any] = [:]

    private init() {}

    /// Track a value keyed by caller source location.
    /// Returns (previousValue, didChange) or nil if first call from this location.
    @discardableResult
    public func track<V: Equatable>(value: V, file: String = #fileID, line: Int = #line) -> (Any, Bool)? {
        let key = "\(file):\(line)"

        if let previous = values[key] {
            guard let oldValue = previous as? V else {
                // Type changed at this location — replace and treat as changed
                values[key] = value
                return (value, true)
            }
            let changed = oldValue != value
            if changed {
                values[key] = value
            }
            return (oldValue, changed)
        } else {
            values[key] = value
            return nil
        }
    }

    /// No-op — keyed by source location, no counter needed.
    public func resetCounter() {}

    /// Full reset (for tests).
    public func clear() {
        values.removeAll()
    }
}
