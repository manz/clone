import Foundation

/// Monotonic clock — replacement for QuartzCore's CACurrentMediaTime().
/// Uses CLOCK_MONOTONIC via clock_gettime, same as the real implementation.
public func CACurrentMediaTime() -> Double {
    var ts = timespec()
    clock_gettime(CLOCK_MONOTONIC, &ts)
    return Double(ts.tv_sec) + Double(ts.tv_nsec) / 1_000_000_000.0
}

/// A rect for animation interpolation.
public struct AnimRect: Equatable, Sendable {
    public var x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat

    public init(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
        self.x = x; self.y = y; self.w = w; self.h = h
    }

    public func lerp(to: AnimRect, t: CGFloat) -> AnimRect {
        AnimRect(
            x: x + (to.x - x) * t,
            y: y + (to.y - y) * t,
            w: w + (to.w - w) * t,
            h: h + (to.h - h) * t
        )
    }
}

/// Tracks an in-flight minimize or restore animation.
public struct WindowAnimation {
    public let windowId: UInt64
    public let from: AnimRect
    public let to: AnimRect
    public let startTime: CFTimeInterval
    public let duration: CFTimeInterval
    public let isMinimizing: Bool  // true = shrinking to dock, false = restoring

    /// Progress 0→1, eased.
    public func progress(at time: CFTimeInterval) -> CGFloat {
        let linear = CGFloat(min(max((time - startTime) / duration, 0), 1))
        // Ease-in-out cubic
        if linear < 0.5 {
            return 4 * linear * linear * linear
        } else {
            let p = -2 * linear + 2
            return 1 - p * p * p / 2
        }
    }

    /// Interpolated rect at the given time.
    public func rect(at time: CFTimeInterval) -> AnimRect {
        from.lerp(to: to, t: progress(at: time))
    }

    /// Interpolated opacity (fade out when minimizing, fade in when restoring).
    public func opacity(at time: CFTimeInterval) -> CGFloat {
        let t = progress(at: time)
        return isMinimizing ? 1.0 - t * 0.3 : 0.7 + t * 0.3
    }

    public func isComplete(at time: CFTimeInterval) -> Bool {
        time >= startTime + duration
    }
}

/// Manages active window animations.
public final class AnimationManager {
    public private(set) var animations: [UInt64: WindowAnimation] = [:]

    public init() {}

    public func startMinimize(windowId: UInt64, from: AnimRect, to: AnimRect) {
        animations[windowId] = WindowAnimation(
            windowId: windowId, from: from, to: to,
            startTime: CACurrentMediaTime(), duration: 0.35,
            isMinimizing: true
        )
    }

    public func startRestore(windowId: UInt64, from: AnimRect, to: AnimRect) {
        animations[windowId] = WindowAnimation(
            windowId: windowId, from: from, to: to,
            startTime: CACurrentMediaTime(), duration: 0.35,
            isMinimizing: false
        )
    }

    /// Get the current animated rect for a window, or nil if not animating.
    public func animatedRect(for windowId: UInt64) -> (AnimRect, CGFloat)? {
        guard let anim = animations[windowId] else { return nil }
        let now = CACurrentMediaTime()
        if anim.isComplete(at: now) { return nil }
        return (anim.rect(at: now), anim.opacity(at: now))
    }

    /// Clean up completed animations. Returns completed windowIds and whether they were minimizing.
    @discardableResult
    public func tick() -> [(windowId: UInt64, wasMinimizing: Bool)] {
        let now = CACurrentMediaTime()
        var completed: [(UInt64, Bool)] = []
        for (id, anim) in animations {
            if anim.isComplete(at: now) {
                completed.append((id, anim.isMinimizing))
            }
        }
        for (id, _) in completed {
            animations.removeValue(forKey: id)
        }
        return completed
    }

    public func isAnimating(_ windowId: UInt64) -> Bool {
        animations[windowId] != nil
    }

    public var hasActiveAnimations: Bool {
        !animations.isEmpty
    }
}
