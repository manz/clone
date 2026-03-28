import Foundation

/// Tracks closures that should only fire once (onAppear, task).
/// Keyed by source location + StateGraph scope for stability across
/// dynamic tree changes (async results, conditional views).
public final class OnceRegistry: @unchecked Sendable {
    public static let shared = OnceRegistry()

    private var fired: Set<String> = []
    /// Per-location call counter (disambiguates multiple .onAppear at same line).
    private var callCounts: [String: Int] = [:]

    private init() {}

    /// Run a closure only once per unique call site.
    /// Uses scope + file:line + call index as key — stable across tree structure changes.
    public func runOnce(_ action: () -> Void, file: String = #fileID, line: Int = #line) {
        let location = "\(StateGraph.shared.currentScope)\(file):\(line)"
        let index = callCounts[location, default: 0]
        callCounts[location] = index + 1
        let key = "\(location):\(index)"

        guard !fired.contains(key) else { return }
        fired.insert(key)
        action()
    }

    /// Reset the call counter for the next frame.
    /// Does NOT clear `fired` — that persists across frames.
    public func resetCounter() {
        callCounts.removeAll()
    }

    /// Full reset (for tests or app restart).
    public func clear() {
        fired.removeAll()
        callCounts.removeAll()
    }
}
