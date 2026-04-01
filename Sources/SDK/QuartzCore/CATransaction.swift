import Foundation
import CoreGraphics

/// Controls implicit animation grouping. Batches layer property changes
/// into transactions that can be committed with or without animation.
public final class CATransaction {

    private struct State {
        var disableActions: Bool = false
        var animationDuration: CFTimeInterval = 0.25
        var animationTimingFunction: CAMediaTimingFunction?
        var completionBlock: (() -> Void)?
    }

    // Thread-local transaction stack
    private static let stackKey = "CATransaction.stack"

    private static var stack: [State] {
        get { Thread.current.threadDictionary[stackKey] as? [State] ?? [] }
        set { Thread.current.threadDictionary[stackKey] = newValue }
    }

    private static var current: State {
        stack.last ?? State()
    }

    private init() {}

    // MARK: - Transaction management

    public static func begin() {
        stack.append(State())
    }

    public static func commit() {
        guard !stack.isEmpty else { return }
        let completed = stack.removeLast()
        completed.completionBlock?()
    }

    public static func flush() {
        while !stack.isEmpty {
            commit()
        }
    }

    // MARK: - Properties

    public static func setDisableActions(_ flag: Bool) {
        if stack.isEmpty { begin() }
        stack[stack.count - 1].disableActions = flag
    }

    public static func disableActions() -> Bool {
        current.disableActions
    }

    public static func setAnimationDuration(_ dur: CFTimeInterval) {
        if stack.isEmpty { begin() }
        stack[stack.count - 1].animationDuration = dur
    }

    public static func animationDuration() -> CFTimeInterval {
        current.animationDuration
    }

    public static func setAnimationTimingFunction(_ function: CAMediaTimingFunction?) {
        if stack.isEmpty { begin() }
        stack[stack.count - 1].animationTimingFunction = function
    }

    public static func animationTimingFunction() -> CAMediaTimingFunction? {
        current.animationTimingFunction
    }

    public static func setCompletionBlock(_ block: (() -> Void)?) {
        if stack.isEmpty { begin() }
        stack[stack.count - 1].completionBlock = block
    }

    public static func completionBlock() -> (() -> Void)? {
        current.completionBlock
    }

    // MARK: - KVC-style access

    public static func value(forKey key: String) -> Any? {
        switch key {
        case "animationDuration": return animationDuration()
        case "disableActions": return disableActions()
        default: return nil
        }
    }

    public static func setValue(_ value: Any?, forKey key: String) {
        switch key {
        case "animationDuration":
            if let dur = value as? CFTimeInterval { setAnimationDuration(dur) }
        case "disableActions":
            if let flag = value as? Bool { setDisableActions(flag) }
        default: break
        }
    }
}
