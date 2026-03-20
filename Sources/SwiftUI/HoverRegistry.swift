import Foundation

/// Phase of a continuous hover interaction — matches Apple's `HoverPhase`.
public enum HoverPhase {
    case active(CGPoint)
    case ended
}

/// Registry for onHover and onContinuousHover handlers.
public final class HoverRegistry: @unchecked Sendable {
    public static let shared = HoverRegistry()

    private var boolHandlers: [UInt64: (Bool) -> Void] = [:]
    private var phaseHandlers: [UInt64: (HoverPhase) -> Void] = [:]
    private var nextId: UInt64 = 1
    /// IDs currently hovered (from the previous pointer move).
    private var activeIds: Set<UInt64> = []

    private init() {}

    /// Register a simple hover handler (Bool enter/leave).
    public func register(_ handler: @escaping (Bool) -> Void) -> UInt64 {
        let id = nextId
        nextId += 1
        boolHandlers[id] = handler
        return id
    }

    /// Register a continuous hover handler (receives position on every move).
    public func registerContinuous(_ handler: @escaping (HoverPhase) -> Void) -> UInt64 {
        let id = nextId
        nextId += 1
        phaseHandlers[id] = handler
        return id
    }

    /// Update hover state with pointer position. Calls all relevant handlers.
    public func update(hitIds: Set<UInt64>, position: CGPoint) {
        // Newly hovered
        for id in hitIds where !activeIds.contains(id) {
            boolHandlers[id]?(true)
        }
        // Still hovered — send position to continuous handlers
        for id in hitIds {
            phaseHandlers[id]?(.active(position))
        }
        // No longer hovered
        for id in activeIds where !hitIds.contains(id) {
            boolHandlers[id]?(false)
            phaseHandlers[id]?(.ended)
        }
        activeIds = hitIds
    }

    /// Clear all handlers (called each frame before rebuilding the view tree).
    public func clear() {
        boolHandlers.removeAll()
        phaseHandlers.removeAll()
        nextId = 1
    }

    /// Clear active state without firing handlers (for frame reset).
    public func resetActive() {
        activeIds.removeAll()
    }
}
