import Foundation

/// Tracks previous values for `.onChange(of:)` modifiers.
/// Each frame, call sites are identified by a counter (like OnceRegistry).
/// Returns the previous value and whether it changed.
public final class OnChangeRegistry: @unchecked Sendable {
    public static let shared = OnChangeRegistry()

    private var values: [Int: Any] = [:]
    private var counter: Int = 0

    private init() {}

    /// Track a value. Returns (previousValue, didChange) or nil if first call.
    @discardableResult
    public func track<V: Equatable>(value: V) -> (Any, Bool)? {
        let index = counter
        counter += 1

        if let previous = values[index] {
            let oldValue = previous as! V
            let changed = oldValue != value
            if changed {
                values[index] = value
            }
            return (oldValue, changed)
        } else {
            values[index] = value
            return nil
        }
    }

    /// Reset counter each frame.
    public func resetCounter() {
        counter = 0
    }

    /// Full reset (for tests).
    public func clear() {
        values.removeAll()
        counter = 0
    }
}
