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

    private var slots: [String: Slot] = [:]
    private var counter: Int = 0
    private var typeStack: [String] = []

    private init() {}

    /// Push a view type onto the stack (called when resolving a View body).
    public func pushView(_ type: String) {
        typeStack.append(type)
    }

    /// Pop a view type from the stack.
    public func popView() {
        if !typeStack.isEmpty { typeStack.removeLast() }
    }

    /// Get or create a state slot.
    /// Key combines the type stack path + counter for uniqueness.
    /// First call: creates slot with `initialValue`.
    /// Subsequent calls: returns existing slot, `initialValue` is ignored.
    public func slot(initialValue: Any) -> Slot {
        let path = typeStack.joined(separator: "/")
        let key = "\(path)#\(counter)"
        counter += 1

        if let existing = slots[key], type(of: existing.value) == type(of: initialValue) {
            return existing
        }

        let slot = Slot(initialValue)
        slots[key] = slot
        return slot
    }

    /// Reset counter for next frame. Does NOT clear slots.
    public func resetCounter() {
        counter = 0
        typeStack.removeAll()
    }

    /// Full reset (for tests).
    public func clear() {
        slots.removeAll()
        counter = 0
    }
}
