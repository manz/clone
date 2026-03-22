import Foundation

/// Persistent state storage across frame rebuilds.
///
/// Each `@State` property wrapper gets a slot keyed by a monotonically
/// increasing counter. Each frame, the counter resets to 0. Since the view tree is
/// rebuilt in the same order each frame, the same sequence of `@State` init calls
/// produces the same keys — mapping each `@State` to its persistent storage.
///
/// First frame: slot is created with the initial value.
/// Subsequent frames: existing slot is returned, initial value is ignored.
public final class StateGraph: @unchecked Sendable {
    public static let shared = StateGraph()

    /// A single state slot — class-backed so it persists when the View struct is recreated.
    public final class Slot {
        public var value: Any
        public init(_ value: Any) { self.value = value }
    }

    private var slots: [Int: Slot] = [:]
    private var counter: Int = 0

    private init() {}

    /// Get or create a state slot.
    /// First call for a given counter position: creates slot with `initialValue`.
    /// Subsequent calls: returns existing slot, `initialValue` is ignored.
    public func slot(initialValue: Any) -> Slot {
        let key = counter
        counter += 1

        if let existing = slots[key] {
            return existing
        }

        let slot = Slot(initialValue)
        slots[key] = slot
        return slot
    }

    /// Reset counter for next frame. Does NOT clear slots.
    public func resetCounter() {
        counter = 0
    }

    /// Full reset (for tests).
    public func clear() {
        slots.removeAll()
        counter = 0
    }
}
