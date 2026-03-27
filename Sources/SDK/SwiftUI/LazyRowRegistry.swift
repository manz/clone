import Foundation

/// Registry for deferred row building in List/LazyVStack.
/// Stores the data + closure so rows are only materialized when visible.
public final class LazyRowRegistry: @unchecked Sendable {
    public static let shared = LazyRowRegistry()
    private init() {}

    /// Row builder: takes an index, returns the ViewNode for that row.
    /// Registered per list key during List.init, consumed during layout.
    private var builders: [String: (Int) -> ViewNode] = [:]
    private var counts: [String: Int] = [:]
    /// Cache of already-built rows (recycled when scrolled off-screen).
    private var cache: [String: [Int: ViewNode]] = [:]

    /// Register a lazy row builder for a list.
    public func register(key: String, count: Int, builder: @escaping (Int) -> ViewNode) {
        builders[key] = builder
        counts[key] = count
        // Keep cache entries that still exist in the new data range
        if let existing = cache[key] {
            cache[key] = existing.filter { $0.key < count }
        }
    }

    /// Get the row count for a list.
    public func count(for key: String) -> Int {
        counts[key] ?? 0
    }

    /// Build (or return cached) ViewNode for a row.
    public func row(for key: String, at index: Int) -> ViewNode {
        if let cached = cache[key]?[index] {
            return cached
        }
        guard let builder = builders[key] else { return .empty }
        let node = builder(index)
        if cache[key] == nil { cache[key] = [:] }
        cache[key]?[index] = node
        return node
    }

    /// Evict cached rows outside the visible range (recycling).
    public func evict(key: String, keeping visibleRange: ClosedRange<Int>) {
        guard var entries = cache[key] else { return }
        // Keep visible + small buffer
        let keepRange = max(0, visibleRange.lowerBound - 5)...visibleRange.upperBound + 5
        entries = entries.filter { keepRange.contains($0.key) }
        cache[key] = entries
    }

    /// Reset per-frame state.
    public func resetCounter() {
        // Builders are re-registered each frame; cache persists
    }

    /// Full reset.
    public func clear() {
        builders.removeAll()
        counts.removeAll()
        cache.removeAll()
    }
}
