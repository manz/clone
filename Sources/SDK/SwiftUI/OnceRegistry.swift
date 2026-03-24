import Foundation

/// Tracks closures that should only fire once (onAppear, task).
/// Uses the closure's code pointer as the identity key.
public final class OnceRegistry: @unchecked Sendable {
    public static let shared = OnceRegistry()

    private var fired: Set<Int> = []
    private var counter: Int = 0

    private init() {}

    /// Run a closure only once. Uses an incrementing counter as key —
    /// the same sequence of runOnce calls each frame produces the same keys,
    /// so each unique call site fires exactly once.
    public func runOnce(_ action: () -> Void) {
        let key = counter
        counter += 1
        guard !fired.contains(key) else { return }
        fired.insert(key)
        action()
    }

    /// Reset the counter for the next frame (called at start of each frame).
    /// Does NOT clear `fired` — that persists across frames.
    public func resetCounter() {
        counter = 0
    }

    /// Full reset (for tests or app restart).
    public func clear() {
        fired.removeAll()
        counter = 0
    }
}
