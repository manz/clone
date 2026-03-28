import Testing
import Foundation
@testable import SwiftUI

/// Simulates the full render + hit-test lifecycle with LayoutCache enabled.
/// This is the exact flow that happens in a real app:
/// 1. Frame N: build view tree → registries reset → layout (with cache) → render
/// 2. User clicks → hit-test against cached LayoutNode from frame N
/// 3. TapRegistry.fire(id) must find a valid handler
@Suite("LayoutCache + Tap Interaction")
struct LayoutCacheTapTests {

    /// Simulate two frames of rendering, then a tap on a cached node.
    @Test @MainActor func tapWorksAfterCacheHit() {
        LayoutCache.shared.clear()
        TapRegistry.shared.clear()

        var tapped = false

        // === Frame 1 ===
        TapRegistry.shared.resetCounter()
        let tapId1 = TapRegistry.shared.register { tapped = true }

        let card = ViewNode.onTap(id: tapId1, child:
            ViewNode.zstack(children: [
                .roundedRect(width: nil, height: nil, radius: 8, fill: .blue),
                .text("Aa", fontSize: 40, color: .primary),
            ]).frame(width: 120, height: 100)
        )
        let tree1 = ViewNode.vstack(alignment: .leading, spacing: 0, children: [card])
        let frame = LayoutFrame(x: 0, y: 0, width: 200, height: 200)

        LayoutCache.shared.swapFrames()
        let layout1 = Layout.layout(tree1, in: frame)

        // Verify tap works on frame 1's layout (tap in center of 120x100 card)
        if case .tap(let id, _) = layout1.hitTestTap(x: 60, y: 50) {
            #expect(id == tapId1)
        } else {
            Issue.record("Frame 1: tap should hit")
        }

        // === Frame 2 (identical tree) ===
        TapRegistry.shared.resetCounter()
        let tapId2 = TapRegistry.shared.register { tapped = true }
        #expect(tapId1 == tapId2, "Deterministic IDs: same counter position = same ID")

        let card2 = ViewNode.onTap(id: tapId2, child:
            ViewNode.zstack(children: [
                .roundedRect(width: nil, height: nil, radius: 8, fill: .blue),
                .text("Aa", fontSize: 40, color: .primary),
            ]).frame(width: 120, height: 100)
        )
        let tree2 = ViewNode.vstack(alignment: .leading, spacing: 0, children: [card2])

        LayoutCache.shared.swapFrames()
        let layout2 = Layout.layout(tree2, in: frame)

        // This MUST work — layout2 may be a cache hit from frame 1
        switch layout2.hitTestTap(x: 60, y: 50) {
        case .tap(let id, _):
            #expect(id == tapId2, "Tap ID should match current frame's registration")
            TapRegistry.shared.fire(id: id)
            #expect(tapped, "Handler should fire")
        case .absorbed:
            Issue.record("Frame 2: .absorbed — onTap not found through cached layout")
        case nil:
            Issue.record("Frame 2: nil — missed entirely")
        }
    }

    /// Multiple tappable cards in a grid — verify each one works after cache.
    @Test @MainActor func multipleTapsWorkAfterCache() {
        LayoutCache.shared.clear()
        TapRegistry.shared.clear()

        var tappedIndex = -1

        // === Frame 1 ===
        TapRegistry.shared.resetCounter()
        let cards = (0..<5).map { i in
            let id = TapRegistry.shared.register { tappedIndex = i }
            return ViewNode.onTap(id: id, child:
                .rect(width: 80, height: 80, fill: .blue)
            )
        }
        let row = ViewNode.hstack(alignment: .center, spacing: 10, children: cards)
        let frame = LayoutFrame(x: 0, y: 0, width: 500, height: 100)

        LayoutCache.shared.swapFrames()
        let layout1 = Layout.layout(row, in: frame)

        // === Frame 2 (identical) ===
        TapRegistry.shared.resetCounter()
        let cards2 = (0..<5).map { i in
            let id = TapRegistry.shared.register { tappedIndex = i }
            return ViewNode.onTap(id: id, child:
                .rect(width: 80, height: 80, fill: .blue)
            )
        }
        let row2 = ViewNode.hstack(alignment: .center, spacing: 10, children: cards2)

        LayoutCache.shared.swapFrames()
        let layout2 = Layout.layout(row2, in: frame)

        // Tap card 3 (approximately at x = 3*90 + 40 = 310)
        if case .tap(let id, _) = layout2.hitTestTap(x: 310, y: 40) {
            TapRegistry.shared.fire(id: id)
            #expect(tappedIndex >= 0, "Some card should have been tapped")
        } else {
            Issue.record("Should hit a card at x=310")
        }
    }

    /// Verify cache doesn't return stale layout when view tree changes.
    @Test @MainActor func cacheInvalidatesOnTreeChange() {
        LayoutCache.shared.clear()
        TapRegistry.shared.clear()

        var tappedA = false
        var tappedB = false

        // === Frame 1: card shows "A" ===
        TapRegistry.shared.resetCounter()
        let idA = TapRegistry.shared.register { tappedA = true }
        let treeA = ViewNode.onTap(id: idA, child: .text("A", fontSize: 14, color: .primary))
        let frame = LayoutFrame(x: 0, y: 0, width: 100, height: 40)

        LayoutCache.shared.swapFrames()
        _ = Layout.layout(treeA, in: frame)

        // === Frame 2: card shows "B" (different ViewNode) ===
        TapRegistry.shared.resetCounter()
        let idB = TapRegistry.shared.register { tappedB = true }
        let treeB = ViewNode.onTap(id: idB, child: .text("B", fontSize: 14, color: .primary))

        LayoutCache.shared.swapFrames()
        let layout2 = Layout.layout(treeB, in: frame)

        // Tap should hit B's handler, not A's
        if case .tap(let id, _) = layout2.hitTestTap(x: 50, y: 20) {
            TapRegistry.shared.fire(id: id)
            #expect(tappedB, "Should fire B's handler")
            #expect(!tappedA, "Should NOT fire A's handler")
        } else {
            Issue.record("Should hit the tap node")
        }
    }

    /// ScrollView content with tappable items — cache shouldn't break scroll + tap.
    @Test @MainActor func tapInsideScrollViewWithCache() {
        LayoutCache.shared.clear()
        TapRegistry.shared.clear()

        var tapped = false

        TapRegistry.shared.resetCounter()
        let tapId = TapRegistry.shared.register { tapped = true }

        let content = ViewNode.onTap(id: tapId, child:
            ViewNode.zstack(children: [
                .roundedRect(width: nil, height: nil, radius: 8, fill: .white),
                .text("Click me", fontSize: 14, color: .primary),
            ]).frame(width: 200, height: 40)
        )
        let scroll = ViewNode.scrollView(axes: .vertical, children: [content], key: "test")
        let frame = LayoutFrame(x: 0, y: 0, width: 300, height: 200)

        LayoutCache.shared.swapFrames()
        let layout = Layout.layout(scroll, in: frame)

        switch layout.hitTestTap(x: 50, y: 20) {
        case .tap(let id, _):
            TapRegistry.shared.fire(id: id)
            #expect(tapped, "Tap should fire inside ScrollView")
        case .absorbed:
            Issue.record(".absorbed inside ScrollView")
        case nil:
            Issue.record("nil — missed inside ScrollView")
        }
    }
}
