import Testing
import Foundation
@testable import SwiftUI

/// Simulates FontBook's font card + tap pattern to verify hit testing works.
@Test @MainActor func fontCardTapRegisters() {
    TapRegistry.shared.clear()
    StateGraph.shared.resetCounter()

    var tapped = false
    let tapId = TapRegistry.shared.register { tapped = true }

    // Build a font card similar to FontBook's:
    // VStack { VStack { Text("Aa") }.background(RoundedRectangle.fill) ; Text("Inter") }
    let card = ViewNode.vstack(alignment: .center, spacing: 4, children: [
        ViewNode.zstack(children: [
            // Background: opaque RoundedRectangle
            .roundedRect(width: nil, height: nil, radius: 8, fill: Color(white: 1.0)),
            // Content
            .vstack(alignment: .center, spacing: 0, children: [
                .spacer(minLength: 0),
                .text("Aa", fontSize: 40, color: .primary),
                .spacer(minLength: 0),
            ])
        ]).frame(width: 120, height: 90),
        .text("Inter", fontSize: 10, color: .primary),
    ]).frame(width: 120)

    // Wrap in .onTap (what .onTapGesture does)
    let tappableCard = ViewNode.onTap(id: tapId, child: card)

    // Layout
    let layout = Layout.layout(tappableCard, in: LayoutFrame(x: 50, y: 50, width: 120, height: 120))

    // Hit test in the center of the card
    let result = layout.hitTestTap(x: 110, y: 90)

    switch result {
    case .tap(let id, _):
        #expect(id == tapId, "Should hit the tap handler, got id \(id) expected \(tapId)")
        TapRegistry.shared.fire(id: id)
        #expect(tapped, "Tap handler should have fired")
    case .absorbed:
        Issue.record("Hit test returned .absorbed — opaque child blocked the parent .onTap")
    case nil:
        Issue.record("Hit test returned nil — tap point missed the card entirely")
    }
}

@Test @MainActor func fontCardInsideScrollViewTapRegisters() {
    TapRegistry.shared.clear()
    StateGraph.shared.resetCounter()

    var tapped = false
    let tapId = TapRegistry.shared.register { tapped = true }

    let card = ViewNode.onTap(id: tapId, child:
        .vstack(alignment: .center, spacing: 4, children: [
            .zstack(children: [
                .roundedRect(width: nil, height: nil, radius: 8, fill: Color(white: 1.0)),
                .text("Aa", fontSize: 40, color: .primary),
            ]).frame(width: 120, height: 90),
            .text("TestFont", fontSize: 10, color: .primary),
        ])
    )

    // Wrap in HStack (row of cards) inside ScrollView
    let scrollContent = ViewNode.vstack(alignment: .leading, spacing: 8, children: [
        .hstack(alignment: .top, spacing: 8, children: [card]),
    ])
    let scrollView = ViewNode.scrollView(axes: .vertical, children: [scrollContent], key: "test_scroll")

    let layout = Layout.layout(scrollView, in: LayoutFrame(x: 0, y: 0, width: 400, height: 300))

    // Hit test where the card should be
    let result = layout.hitTestTap(x: 60, y: 45)

    switch result {
    case .tap(let id, _):
        TapRegistry.shared.fire(id: id)
        #expect(tapped, "Tap should fire through ScrollView")
    case .absorbed:
        Issue.record("Hit test .absorbed inside ScrollView — onTap not found")
    case nil:
        Issue.record("Hit test nil inside ScrollView — missed entirely")
    }
}

/// Test that the frame modifier doesn't break hit testing with .onTap
@Test @MainActor func frameThenOnTapWorks() {
    TapRegistry.shared.clear()

    var tapped = false
    let tapId = TapRegistry.shared.register { tapped = true }

    let view = ViewNode.onTap(id: tapId, child:
        ViewNode.rect(width: 100, height: 50, fill: .blue)
    )

    let layout = Layout.layout(view, in: LayoutFrame(x: 0, y: 0, width: 100, height: 50))
    let result = layout.hitTestTap(x: 50, y: 25)

    switch result {
    case .tap(let id, _):
        TapRegistry.shared.fire(id: id)
        #expect(tapped)
    case .absorbed:
        Issue.record(".absorbed should upgrade to .tap because parent is .onTap")
    case nil:
        Issue.record("nil — missed")
    }
}
