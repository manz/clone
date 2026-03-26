import Foundation

/// A timer that fires in sync with the display refresh rate.
/// On Clone, backed by a DispatchSourceTimer at the preferred frame rate.
public class CADisplayLink {

    private var timer: DispatchSourceTimer?
    private weak var target: AnyObject?
    private let selector: Selector

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
        self.selector = sel
    }

    /// Add the display link to a run loop. On Clone this starts the
    /// internal DispatchSourceTimer. The `forMode` parameter is accepted
    /// for API compatibility but all modes are treated equally.
    public func add(to runloop: RunLoop, forMode mode: RunLoop.Mode) {
        guard timer == nil else { return }
        updateInterval()

        let source = DispatchSource.makeTimerSource(queue: .main)
        let interval = duration
        source.schedule(
            deadline: .now(),
            repeating: interval,
            leeway: .milliseconds(1)
        )
        source.setEventHandler { [weak self] in
            self?.tick()
        }
        timer = source
        if !isPaused {
            source.resume()
        }
    }

    /// Remove the display link from all run loops and release resources.
    public func invalidate() {
        if let t = timer {
            t.cancel()
            timer = nil
        }
        target = nil
    }

    private func tick() {
        let now = CACurrentMediaTime()
        timestamp = now
        targetTimestamp = now + duration
        _ = target?.perform(selector)
    }

    private func updateInterval() {
        let fps = preferredFramesPerSecond > 0 ? preferredFramesPerSecond : 60
        duration = 1.0 / CFTimeInterval(fps)
        if let t = timer {
            t.schedule(
                deadline: .now(),
                repeating: duration,
                leeway: .milliseconds(1)
            )
        }
    }

    deinit {
        timer?.cancel()
    }
}
