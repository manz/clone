import Foundation

/// Tracks scroll offsets per ScrollView instance.
/// Keyed by source location (file:line) for stability across frame rebuilds.
public final class ScrollRegistry: @unchecked Sendable {
    public static let shared = ScrollRegistry()

    private var offsets: [String: CGFloat] = [:]
    private var counter: Int = 0

    private init() {}

    /// Reset counter each frame. Call from App.swift alongside other registry resets.
    public func resetCounter() {
        counter = 0
        frames.removeAll()
        contentHeights.removeAll()
    }

    /// Get next scroll key (stable across resizes, based on evaluation order).
    public func nextKey() -> String {
        let key = "scroll_\(counter)"
        counter += 1
        return key
    }

    /// Get scroll offset for a ScrollView by key.
    public func offset(scrollKey: String) -> CGFloat {
        offsets[scrollKey, default: 0]
    }

    /// Scroll by delta at a given screen position. Returns true if a ScrollView handled it.
    public func scroll(deltaY: CGFloat, atX x: CGFloat, atY y: CGFloat) -> Bool {
        // Find the ScrollView that contains this point using the stored frames
        for (key, frame) in frames {
            if x >= frame.x && x <= frame.x + frame.width &&
               y >= frame.y && y <= frame.y + frame.height {
                let current = offsets[key, default: 0]
                let contentHeight = contentHeights[key, default: 0]
                let maxOffset = max(0, contentHeight - frame.height)
                let newOffset = min(max(current - deltaY, 0), maxOffset)
                offsets[key] = newOffset
                return true
            }
        }
        return false
    }

    /// Register a ScrollView's frame and content height for hit testing.
    private var frames: [String: LayoutFrame] = [:]
    private var contentHeights: [String: CGFloat] = [:]

    public func registerFrame(_ frame: LayoutFrame, contentHeight: CGFloat, key: String) {
        frames[key] = frame
        contentHeights[key] = contentHeight
    }

    /// Full reset (for tests).
    public func clear() {
        offsets.removeAll()
        frames.removeAll()
        contentHeights.removeAll()
        counter = 0
    }
}
