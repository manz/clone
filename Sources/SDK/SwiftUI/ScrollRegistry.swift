import Foundation

/// Tracks scroll offsets per ScrollView instance.
/// Keyed by source location (file:line) for stability across frame rebuilds.
public final class ScrollRegistry: @unchecked Sendable {
    public static let shared = ScrollRegistry()

    public struct ScrollOffset {
        public var x: CGFloat = 0
        public var y: CGFloat = 0
    }

    private var offsets: [String: ScrollOffset] = [:]

    private init() {}

    /// Reset per-frame state (frames for hit testing). Offsets persist.
    public func resetCounter() {
        frames.removeAll()
        contentSizes.removeAll()
        axesSets.removeAll()
    }

    /// Get scroll offset for a ScrollView by key.
    public func offset(scrollKey: String) -> ScrollOffset {
        offsets[scrollKey, default: ScrollOffset()]
    }

    /// Scroll by delta at a given screen position. Returns true if a ScrollView handled it.
    public func scroll(deltaX: CGFloat = 0, deltaY: CGFloat, atX x: CGFloat, atY y: CGFloat) -> Bool {
        for (key, frame) in frames {
            if x >= frame.x && x <= frame.x + frame.width &&
               y >= frame.y && y <= frame.y + frame.height {
                var current = offsets[key, default: ScrollOffset()]
                let contentSize = contentSizes[key] ?? (width: 0, height: 0)
                let axes = axesSets[key] ?? .vertical

                if axes.contains(.vertical) {
                    let maxY = max(0, contentSize.height - frame.height)
                    current.y = min(max(current.y - deltaY, 0), maxY)
                }
                if axes.contains(.horizontal) {
                    let maxX = max(0, contentSize.width - frame.width)
                    current.x = min(max(current.x - deltaX, 0), maxX)
                }

                offsets[key] = current
                return true
            }
        }
        return false
    }

    /// Register a ScrollView's frame and content size for hit testing.
    private var frames: [String: LayoutFrame] = [:]
    private var contentSizes: [String: (width: CGFloat, height: CGFloat)] = [:]
    private var axesSets: [String: Axis.Set] = [:]

    public func registerFrame(_ frame: LayoutFrame, contentWidth: CGFloat, contentHeight: CGFloat, axes: Axis.Set, key: String) {
        frames[key] = frame
        contentSizes[key] = (contentWidth, contentHeight)
        axesSets[key] = axes
    }

    /// Full reset (for tests).
    public func clear() {
        offsets.removeAll()
        frames.removeAll()
        contentSizes.removeAll()
        axesSets.removeAll()
    }
}
