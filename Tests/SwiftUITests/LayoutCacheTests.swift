import Testing
@testable import SwiftUI

@Suite("LayoutCache")
struct LayoutCacheTests {

    @Test func cacheHitOnIdenticalNodeAndFrame() {
        let cache = LayoutCache.shared
        cache.clear()

        let node = ViewNode.text("Hello", fontSize: 14, color: .primary)
        let frame = LayoutFrame(x: 0, y: 0, width: 200, height: 40)

        // First layout — cache miss, store result
        let result = Layout.layout(node, in: frame)
        #expect(cache.missesThisFrame >= 1)

        // Swap to next frame
        cache.swapFrames()

        // Same node, same frame — should cache hit
        let cached = Layout.layout(node, in: frame)
        #expect(cache.hitsThisFrame >= 1)
        #expect(cached == result)
    }

    @Test func cacheMissOnDifferentNode() {
        let cache = LayoutCache.shared
        cache.clear()

        let frame = LayoutFrame(x: 0, y: 0, width: 200, height: 40)

        let node1 = ViewNode.text("Hello", fontSize: 14, color: .primary)
        _ = Layout.layout(node1, in: frame)

        cache.swapFrames()

        // Different text — cache miss
        let node2 = ViewNode.text("World", fontSize: 14, color: .primary)
        let hitsBefore = cache.hitsThisFrame
        _ = Layout.layout(node2, in: frame)
        // Should not have gained a hit for this specific lookup
        // (may have hits from child nodes, but node2 itself should miss)
        #expect(cache.missesThisFrame >= 1)
    }

    @Test func cacheMissOnDifferentFrame() {
        let cache = LayoutCache.shared
        cache.clear()

        let node = ViewNode.text("Hello", fontSize: 14, color: .primary)
        let frame1 = LayoutFrame(x: 0, y: 0, width: 200, height: 40)
        let frame2 = LayoutFrame(x: 0, y: 0, width: 300, height: 40) // wider

        _ = Layout.layout(node, in: frame1)
        cache.swapFrames()

        // Same node, different frame — cache miss
        _ = Layout.layout(node, in: frame2)
        #expect(cache.missesThisFrame >= 1)
    }

    @Test func swapFramesResetsCounters() {
        let cache = LayoutCache.shared
        cache.clear()

        let node = ViewNode.text("Hello", fontSize: 14, color: .primary)
        let frame = LayoutFrame(x: 0, y: 0, width: 200, height: 40)
        _ = Layout.layout(node, in: frame)
        #expect(cache.missesThisFrame >= 1)

        cache.swapFrames()
        // Counters reset after swap
        #expect(cache.hitsThisFrame == 0)
        #expect(cache.missesThisFrame == 0)
    }

    @Test func subtreeHitsSkipChildLayout() {
        let cache = LayoutCache.shared
        cache.clear()

        // A VStack with 3 children — if the entire VStack is cached,
        // none of the children should be individually laid out
        let tree = ViewNode.vstack(alignment: .leading, spacing: 0, children: [
            .text("A", fontSize: 14, color: .primary),
            .text("B", fontSize: 14, color: .primary),
            .text("C", fontSize: 14, color: .primary),
        ])
        let frame = LayoutFrame(x: 0, y: 0, width: 200, height: 300)

        // First frame — full layout
        let result1 = Layout.layout(tree, in: frame)
        let misses1 = cache.missesThisFrame

        cache.swapFrames()

        // Second frame — should hit on the VStack root, skip children
        let result2 = Layout.layout(tree, in: frame)
        #expect(cache.hitsThisFrame >= 1)
        #expect(result2 == result1)
        // Misses should be less than first frame (subtree skipped)
        #expect(cache.missesThisFrame < misses1)
    }

    @Test func clearResetsEverything() {
        let cache = LayoutCache.shared
        let node = ViewNode.text("Test", fontSize: 14, color: .primary)
        let frame = LayoutFrame(x: 0, y: 0, width: 100, height: 30)
        _ = Layout.layout(node, in: frame)

        cache.clear()
        cache.swapFrames()

        // After clear + swap, nothing should hit
        _ = Layout.layout(node, in: frame)
        #expect(cache.hitsThisFrame == 0)
    }
}
