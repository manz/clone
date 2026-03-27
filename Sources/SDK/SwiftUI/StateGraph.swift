import Foundation

/// Persistent state storage across frame rebuilds.
///
/// Keys combine three components:
/// 1. **Scope path** — pushed by ForEach with item IDs (e.g. "track-42/")
/// 2. **Source location** — file:line from #fileID:#line
/// 3. **Call index** — disambiguates multiple @State at same file:line outside ForEach
///
/// Example key: "track-42/TrackRow.swift:8:0"
///
/// ForEach pushes each item's Identifiable.id as a scope before calling the
/// content closure, making state stable across reorders, insertions, deletions.
/// The call-index counter still handles non-ForEach cases (multiple @State
/// declarations at different lines in the same view).
public final class StateGraph: @unchecked Sendable {
    public static let shared = StateGraph()

    public final class Slot {
        public var value: Any
        public init(_ value: Any) { self.value = value }
    }

    private var slots: [String: Slot] = [:]
    /// Tracks how many times each scoped file:line has been called this frame.
    private var callCounts: [String: Int] = [:]
    /// Scope stack — ForEach pushes item IDs, producing "id1/id2/" prefixes.
    private var scopeStack: [String] = []
    /// Cached scope prefix, rebuilt on push/pop.
    private var scopePrefix: String = ""

    /// Current scope path (e.g. "album-7/track-42/") for external keying.
    public var currentScope: String { scopePrefix }

    /// When true, async state changed and the frame needs a re-render.
    /// Checked by the display link alongside needsRender.
    public var needsAsyncRender: Bool = false

    /// Signal that async state changed (network fetch completed, timer fired, etc.)
    /// Triggers a re-render on the next display link tick.
    public func invalidate() {
        needsAsyncRender = true
    }

    private init() {}

    /// Push an identity scope (used by ForEach for each item's id).
    public func pushScope(_ id: String) {
        scopeStack.append(id)
        rebuildScopePrefix()
    }

    /// Pop the most recent identity scope.
    public func popScope() {
        if !scopeStack.isEmpty {
            scopeStack.removeLast()
            rebuildScopePrefix()
        }
    }

    private func rebuildScopePrefix() {
        scopePrefix = scopeStack.isEmpty ? "" : scopeStack.joined(separator: "/") + "/"
    }

    /// Get or create a state slot keyed by scope + source location + call index.
    public func slot(initialValue: Any, file: String = #fileID, line: Int = #line) -> Slot {
        let locationKey = "\(scopePrefix)\(file):\(line)"
        let index = callCounts[locationKey, default: 0]
        callCounts[locationKey] = index + 1

        let key = "\(locationKey):\(index)"

        if let existing = slots[key] {
            return existing
        }

        let slot = Slot(initialValue)
        slots[key] = slot
        return slot
    }

    /// Reset call counts each frame so the same call sequence maps to same slots.
    public func resetCounter() {
        callCounts.removeAll(keepingCapacity: true)
        scopeStack.removeAll(keepingCapacity: true)
        scopePrefix = ""
    }

    /// No-op — view scoping handled by pushScope/popScope.
    public func pushView(_ type: String) {}
    public func popView() {}

    /// Full reset (for tests).
    public func clear() {
        slots.removeAll()
        callCounts.removeAll()
        scopeStack.removeAll()
        scopePrefix = ""
    }
}
