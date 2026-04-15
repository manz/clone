import Foundation
import PosixShim
import CoreGraphics

/// Registry for onTap handlers. Maps tap IDs to closures.
public final class TapRegistry: @unchecked Sendable {
    public static let shared = TapRegistry()

    private enum TapHandler {
        case simple(() -> Void)
        case spatial((CGPoint) -> Void)
    }

    private var handlers: [UInt64: TapHandler] = [:]
    /// Required click count per handler (default 1 = single click).
    private var requiredCounts: [UInt64: Int] = [:]
    private var nextId: UInt64 = 1

    private init() {}

    /// Register a tap handler and return its ID.
    public func register(_ handler: @escaping () -> Void, count: Int = 1) -> UInt64 {
        let id = nextId
        nextId += 1
        handlers[id] = .simple(handler)
        requiredCounts[id] = count
        return id
    }

    /// Register a spatial tap handler (receives tap location in local coordinates).
    public func registerSpatial(_ handler: @escaping (CGPoint) -> Void, count: Int = 1) -> UInt64 {
        let id = nextId
        nextId += 1
        handlers[id] = .spatial(handler)
        requiredCounts[id] = count
        return id
    }

    /// Required click count for the given handler (1 = single, 2 = double).
    public func requiredCount(for id: UInt64) -> Int {
        requiredCounts[id] ?? 1
    }

    /// Fire a tap handler by ID, optionally with location.
    public func fire(id: UInt64, at point: CGPoint = .zero) {
        guard let handler = handlers[id] else {
            logErr("[TapRegistry] fire id=\(id) — NO HANDLER FOUND (registered: \(handlers.count) handlers)\n")
            return
        }
        logErr("[TapRegistry] fire id=\(id) — executing handler\n")
        switch handler {
        case .simple(let action): action()
        case .spatial(let action): action(point)
        }
    }

    /// Get the closure for a tap ID (for capturing in long-lived registries like menus).
    public func handler(for id: UInt64) -> (() -> Void)? {
        guard let handler = handlers[id] else { return nil }
        switch handler {
        case .simple(let action): return action
        case .spatial(let action): return { action(.zero) }
        }
    }

    /// Number of registered handlers.
    public var count: Int { handlers.count }

    /// Reset counter so the same call sequence produces the same IDs.
    /// Handlers survive — new registrations overwrite at the same IDs.
    public func resetCounter() {
        nextId = 1
    }

    /// Full reset (for tests).
    public func clear() {
        handlers.removeAll()
        nextId = 1
    }
}
