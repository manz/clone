import Foundation
import CoreGraphics

/// A timer that fires in sync with the display refresh rate.
/// On Clone, backed by a DispatchSourceTimer at the preferred frame rate.
public class CADisplayLink {

    private var timer: DispatchSourceTimer?
    private weak var target: AnyObject?
    private let selectorName: String
    private var callback: (() -> Void)?

    /// The timestamp of the last frame that was displayed.
    public private(set) var timestamp: CFTimeInterval = 0

    /// The time at which the next frame should be displayed.
    public private(set) var targetTimestamp: CFTimeInterval = 0

    /// The duration between frames (1/fps).
    public private(set) var duration: CFTimeInterval = 1.0 / 60.0

    /// Preferred frame rate. 0 = display's native rate. Default is 0.
    public var preferredFramesPerSecond: Int = 0 {
        didSet { updateInterval() }
    }

    /// Pause or resume the display link.
    public var isPaused: Bool = false {
        didSet {
            if isPaused {
                timer?.suspend()
            } else {
                timer?.resume()
            }
        }
    }

    public init(target: Any, selector sel: Selector) {
        self.target = target as AnyObject
        self.selectorName = "\(sel)"
        #if canImport(ObjectiveC)
        // On macOS, use ObjC perform(selector:) — resolved at runtime
        #else
        // On Linux, no ObjC runtime — resolve by convention: the selector name
        // maps to a known method. CADisplayLink is only used by AppSideRenderer
        // with selector "tick", so we match that.
        #endif
    }

    public func add(to runLoop: RunLoop, forMode mode: RunLoop.Mode) {
        let source = DispatchSource.makeTimerSource(queue: .main)
        let fps = preferredFramesPerSecond > 0 ? preferredFramesPerSecond : 60
        duration = 1.0 / CFTimeInterval(fps)
        let interval = DispatchTimeInterval.milliseconds(Int(duration * 1000))
        source.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(1))
        source.setEventHandler { [weak self] in
            self?.tick()
        }
        source.resume()
        timer = source
    }

    public func invalidate() {
        timer?.cancel()
        timer = nil
        target = nil
        callback = nil
    }

    private func tick() {
        let now = CACurrentMediaTime()
        timestamp = now
        targetTimestamp = now + duration
        if let cb = callback {
            cb()
        } else {
            #if canImport(ObjectiveC)
            _ = target?.perform(Selector(selectorName))
            #endif
        }
    }

    private func updateInterval() {
        let fps = preferredFramesPerSecond > 0 ? preferredFramesPerSecond : 60
        duration = 1.0 / CFTimeInterval(fps)
        if let t = timer {
            t.schedule(
                deadline: .now(),
                repeating: .milliseconds(Int(duration * 1000)),
                leeway: .milliseconds(1)
            )
        }
    }

    /// Set a closure-based callback (used on Linux where ObjC selectors aren't available).
    public func setCallback(_ cb: @escaping () -> Void) {
        self.callback = cb
    }
}
