import Foundation
import CoreGraphics

/// Phase of a continuous hover interaction — matches Apple's `HoverPhase`.
public enum HoverPhase: Equatable {
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

    /// Reset counter so the same call sequence produces the same IDs.
    /// Handlers survive — new registrations overwrite at the same IDs.
    /// activeIds is preserved so hover state stays consistent across frames.
    public func resetCounter() {
        nextId = 1
    }

    /// Full reset (for tests).
    public func clear() {
        boolHandlers.removeAll()
        phaseHandlers.removeAll()
        activeIds.removeAll()
        nextId = 1
    }
}
