import Foundation
#if !canImport(CoreGraphics)
import CloneCoreGraphics
#endif

/// Monotonic clock — matches QuartzCore's CACurrentMediaTime().
/// Uses CLOCK_MONOTONIC via clock_gettime, same as the real implementation.
public func CACurrentMediaTime() -> CFTimeInterval {
    var ts = timespec()
    clock_gettime(CLOCK_MONOTONIC, &ts)
    return Double(ts.tv_sec) + Double(ts.tv_nsec) / 1_000_000_000.0
}
