import Testing
import Foundation
@testable import SwiftUI

/// Hit-testing regression tests for buttons — especially icon-bearing ones.
/// The live bug: hover highlights correctly on an icon button but clicks miss.
/// These tests pin down that hitTestTap and hitTestHover resolve the same
/// region for the same content, and that the tap target covers the full
/// visual bounds of the button (icon + label).
@Suite("Icon Button Hit Testing")
struct IconButtonHitTests {

    /// HStack-wrapped icon + label must be tappable anywhere inside the HStack.
    @Test @MainActor func iconAndLabelBothHit() {
        TapRegistry.shared.clear()
        TapRegistry.shared.resetCounter()

        var fired = false
        let tapId = TapRegistry.shared.register { fired = true }

        // Mirrors Button(_ label, systemImage:) construction.
        let row = ViewNode.onTap(id: tapId, child:
            ViewNode.hstack(alignment: .center, spacing: 4, children: [
                .image(name: "star", width: 17, height: 17),
                .text("Star", fontSize: 13, color: .primary),
            ])
        )
        let frame = LayoutFrame(x: 0, y: 0, width: 200, height: 40)
        let layout = Layout.layout(row, in: frame)

        // Tap on the icon (~x=8, y=10): tap frame must contain it.
        switch layout.hitTestTap(x: 8, y: 10) {
        case .tap(let id, let hitFrame):
            #expect(id == tapId)
            #expect(hitFrame.contains(x: 8, y: 10))
            TapRegistry.shared.fire(id: id)
            #expect(fired)
        default:
            Issue.record("Icon click missed — hitTestTap returned non-tap")
        }

        // Tap on the label (~x=40, y=10).
        fired = false
        switch layout.hitTestTap(x: 40, y: 10) {
        case .tap(let id, let hitFrame):
            #expect(id == tapId)
            #expect(hitFrame.contains(x: 40, y: 10))
            TapRegistry.shared.fire(id: id)
            #expect(fired)
        default:
            Issue.record("Label click missed")
        }
    }

    /// Hover and tap must agree on whether a point is inside the button.
    /// The production bug shows as "hover highlights but click misses",
    /// which can only happen if hover and tap disagree on the hit region.
    @Test @MainActor func hoverAndTapAgreeOnSameRegion() {
        TapRegistry.shared.clear()
        HoverRegistry.shared.clear()
        TapRegistry.shared.resetCounter()
        HoverRegistry.shared.resetCounter()

        let tapId = TapRegistry.shared.register { }
        let hoverId = HoverRegistry.shared.register { _ in }

        // Mirror Button(systemImage:) — HStack wrapped in onTap AND onHover at the
        // same level (SwiftUI-style modifier stacking). Both should cover the same region.
        let iconRow = ViewNode.hstack(alignment: .center, spacing: 4, children: [
            .image(name: "gear", width: 17, height: 17),
            .text("Settings", fontSize: 13, color: .primary),
        ])
        let hovered = ViewNode.onHover(id: hoverId, child: iconRow)
        let tree = ViewNode.onTap(id: tapId, child: hovered)

        let frame = LayoutFrame(x: 0, y: 0, width: 300, height: 40)
        let layout = Layout.layout(tree, in: frame)

        // Probe a grid of points; every point the hover reports as inside
        // must also be reported inside by the tap hit-test.
        for x: CGFloat in stride(from: 2, to: 100, by: 4) {
            for y: CGFloat in stride(from: 2, to: 38, by: 4) {
                let hovers = layout.hitTestHover(x: x, y: y)
                let hoverHit = hovers[hoverId] != nil
                let tap = layout.hitTestTap(x: x, y: y)
                let tapHit: Bool
                switch tap {
                case .tap(let id, _): tapHit = (id == tapId)
                case .taps(let hits): tapHit = hits.contains(where: { $0.id == tapId })
                default: tapHit = false
                }
                #expect(hoverHit == tapHit, "Mismatch at (\(x),\(y)): hover=\(hoverHit) tap=\(tapHit)")
            }
        }
    }

    /// When content sits below a sibling title bar (simulating the app's window
    /// layout), click coordinates from the compositor (window-local, including
    /// chrome at y=0..38) must hit the button at its actual rendered position.
    @Test @MainActor func buttonBelowTitleBarHitsAtCorrectY() {
        TapRegistry.shared.clear()
        TapRegistry.shared.resetCounter()

        var fired = false
        let tapId = TapRegistry.shared.register { fired = true }

        // 38px title bar + 40px button row, matching App.swift's prepend.
        let titleBar = ViewNode.rect(width: nil, height: nil, fill: .gray)
            .frame(width: 400, height: 38)
        let button = ViewNode.onTap(id: tapId, child:
            ViewNode.hstack(alignment: .center, spacing: 4, children: [
                .image(name: "plus", width: 17, height: 17),
                .text("Add", fontSize: 13, color: .primary),
            ])
        ).frame(width: 100, height: 30)

        let tree = ViewNode.vstack(alignment: .leading, spacing: 0, children: [titleBar, button])
        let frame = LayoutFrame(x: 0, y: 0, width: 400, height: 300)
        let layout = Layout.layout(tree, in: frame)

        // Click at (10, 50) — inside button, which starts at y=38.
        switch layout.hitTestTap(x: 10, y: 50) {
        case .tap(let id, let hitFrame):
            #expect(id == tapId)
            #expect(hitFrame.y >= 38, "Button frame should start at or below title bar")
            #expect(hitFrame.contains(x: 10, y: 50))
            TapRegistry.shared.fire(id: id)
            #expect(fired)
        default:
            Issue.record("Click at (10,50) below title bar should hit the button")
        }

        // Click in title bar region (y=10) must NOT hit the button.
        fired = false
        switch layout.hitTestTap(x: 10, y: 10) {
        case .tap:
            Issue.record("Click in title bar region should not hit content button")
        default:
            break
        }
        #expect(!fired)
    }

    /// Button with explicit .frame — tap frame must match the frame-imposed size,
    /// not the intrinsic content size. Catches the "icon measures smaller than
    /// button visual → tap hits icon only" class of bugs.
    @Test @MainActor func buttonWithExplicitFrameCoversWholeFrame() {
        TapRegistry.shared.clear()
        TapRegistry.shared.resetCounter()

        let tapId = TapRegistry.shared.register { }

        // 120x40 button visual, but intrinsic content (icon+text) is smaller.
        let content = ViewNode.hstack(alignment: .center, spacing: 4, children: [
            .image(name: "star", width: 17, height: 17),
            .text("Go", fontSize: 13, color: .primary),
        ])
        let sized = ViewNode.onTap(id: tapId, child: content)
            .frame(width: 120, height: 40)

        let frame = LayoutFrame(x: 0, y: 0, width: 200, height: 80)
        let layout = Layout.layout(sized, in: frame)

        // Corners of the frame should all hit.
        for (x, y) in [(1.0, 1.0), (118.0, 1.0), (1.0, 38.0), (118.0, 38.0), (60.0, 20.0)] {
            switch layout.hitTestTap(x: CGFloat(x), y: CGFloat(y)) {
            case .tap(let id, _):
                #expect(id == tapId, "Expected tap at (\(x),\(y))")
            default:
                Issue.record("Missed tap at (\(x),\(y)) — frame should cover whole 120x40")
            }
        }

        // Outside the frame must miss.
        switch layout.hitTestTap(x: 150, y: 20) {
        case .tap:
            Issue.record("Click outside 120x40 frame should miss")
        default:
            break
        }
    }

    /// VStack of icon buttons — each must hit at its own row, never neighbours.
    @Test @MainActor func iconButtonRowsDoNotLeakAcross() {
        TapRegistry.shared.clear()
        TapRegistry.shared.resetCounter()

        var tappedIndex = -1
        let ids = (0..<4).map { i in
            TapRegistry.shared.register { tappedIndex = i }
        }

        let rows: [ViewNode] = ids.enumerated().map { (i, id) in
            ViewNode.onTap(id: id, child:
                ViewNode.hstack(alignment: .center, spacing: 4, children: [
                    .image(name: "circle", width: 17, height: 17),
                    .text("Row \(i)", fontSize: 13, color: .primary),
                ])
            ).frame(width: 200, height: 30)
        }
        let tree = ViewNode.vstack(alignment: .leading, spacing: 4, children: rows)
        let frame = LayoutFrame(x: 0, y: 0, width: 200, height: 400)
        let layout = Layout.layout(tree, in: frame)

        for i in 0..<4 {
            // Each row is 30 tall with 4px spacing; center of row i is at y = i*(30+4) + 15.
            let y = CGFloat(i) * 34 + 15
            tappedIndex = -1
            switch layout.hitTestTap(x: 20, y: y) {
            case .tap(let id, _):
                TapRegistry.shared.fire(id: id)
                #expect(tappedIndex == i, "Row \(i): tapped index \(tappedIndex), expected \(i) at y=\(y)")
            default:
                Issue.record("Row \(i): missed at y=\(y)")
            }
        }
    }
}
