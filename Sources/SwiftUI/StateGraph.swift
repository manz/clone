import Foundation

/// Persistent state storage across frame rebuilds.
///
/// Slots are keyed by caller file+line, making them stable regardless of
/// view tree rebuild order. This matches Apple's approach of using structural
/// identity (source location) for state storage.
public final class StateGraph: @unchecked Sendable {
    public static let shared = StateGraph()

    public final class Slot {
        public var value: Any
        public init(_ value: Any) { self.value = value }
    }

    private var slots: [String: Slot] = [:]

    private init() {}

    /// Get or create a state slot keyed by caller source location.
    /// First call from a given file+line: creates slot with `initialValue`.
    /// Subsequent calls from same location: returns existing slot.
    public func slot(initialValue: Any, file: String = #fileID, line: Int = #line) -> Slot {
        let key = "\(file):\(line)"

        if let existing = slots[key] {
            return existing
        }

        let slot = Slot(initialValue)
        slots[key] = slot
        return slot
    }

    /// No-op — slots are keyed by source location, not counter.
    public func resetCounter() {}

    /// No-op — view scoping not needed with source-location keys.
    public func pushView(_ type: String) {}
    public func popView() {}

    /// Full reset (for tests).
    public func clear() {
        slots.removeAll()
    }
}
