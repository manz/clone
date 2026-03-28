import Testing
import Foundation
import Combine
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

/// Test that mutating @Published state produces a different view tree (the FontBook bug).
@Test @MainActor func publishedStateMutationChangesViewTree() {
    TapRegistry.shared.clear()
    StateGraph.shared.clear()
    LayoutCache.shared.clear()

    // Simulate FontBookState
    final class TestFontState: ObservableObject {
        @Published var selectedFamily: String? = nil
    }

    let state = TestFontState()

    // Build a font card — the selected flag changes the background color
    func buildCard(family: String) -> ViewNode {
        let selected = state.selectedFamily == family
        let bgColor = selected ? Color(red: 0.04, green: 0.52, blue: 1.0, opacity: 0.2) : Color(white: 1.0)
        return ViewNode.vstack(alignment: .center, spacing: 4, children: [
            .zstack(children: [
                .roundedRect(width: nil, height: nil, radius: 8, fill: bgColor),
                .text("Aa", fontSize: 40, color: .primary),
            ]).frame(width: 120, height: 90),
            .text(family, fontSize: 10, color: .primary),
        ])
    }

    // Frame 1: no selection
    let tree1 = ViewNode.hstack(alignment: .top, spacing: 8, children: [
        buildCard(family: "Inter"),
        buildCard(family: "Iosevka"),
    ])
    let layout1 = Layout.layout(tree1, in: LayoutFrame(x: 0, y: 0, width: 400, height: 200))

    // Mutate state — select "Iosevka"
    state.selectedFamily = "Iosevka"

    // Frame 2: Iosevka selected
    let tree2 = ViewNode.hstack(alignment: .top, spacing: 8, children: [
        buildCard(family: "Inter"),
        buildCard(family: "Iosevka"),
    ])
    let layout2 = Layout.layout(tree2, in: LayoutFrame(x: 0, y: 0, width: 400, height: 200))

    // The trees must differ — selected card has different background color
    #expect(tree1 != tree2, "View tree should change after state mutation")

    // The flattened commands must differ
    let cmds1 = CommandFlattener.flatten(layout1)
    let cmds2 = CommandFlattener.flatten(layout2)
    #expect(cmds1 != cmds2, "Render commands should differ after state mutation")
}

/// Test that @StateObject + objectWillChange triggers StateGraph.invalidate()
@Test @MainActor func stateObjectSubscribesToObjectWillChange() {
    StateGraph.shared.clear()
    LayoutCache.shared.clear()

    final class TestState: ObservableObject {
        @Published var count = 0
    }

    // Create the StateObject — it should subscribe to objectWillChange
    StateGraph.shared.resetCounter()
    let slot = StateGraph.shared.slot(initialValue: TestState())
    let obj = slot.value as! TestState

    // Manually subscribe like StateObject.init does
    slot.subscription = obj.objectWillChange.sink { _ in
        StateGraph.shared.invalidate()
    }

    StateGraph.shared.needsAsyncRender = false

    // Mutate a @Published property
    obj.count = 42

    // objectWillChange should have fired → invalidate() → needsAsyncRender = true
    #expect(StateGraph.shared.needsAsyncRender, "@Published change should trigger needsAsyncRender")
}

/// Reproduces FontBook's exact render pipeline across two frames with LayoutCache enabled.
/// Frame 1: no selection → grid visible, no detail.
/// Tap mutates state.
/// Frame 2: "Iosevka" selected → grid opacity 0, detail visible.
/// Verifies LayoutCache doesn't return stale results.
@Test @MainActor func layoutCacheDoesNotStaleOnStateMutation() {
    let cache = LayoutCache.shared
    cache.clear()
    TapRegistry.shared.clear()
    StateGraph.shared.clear()
    GeometryReaderRegistry.shared.clear()

    final class FBState: ObservableObject {
        @Published var selectedFamily: String? = nil
        @Published var detailFamily: String? = nil
    }
    let state = FBState()

    let families = ["Inter", "Iosevka", "Helvetica"]
    let cardSize: CGFloat = 130

    // Helper: build the full FontBook-like tree from state
    func buildTree() -> ViewNode {
        let sidebarWidth: CGFloat = 180
        let width: CGFloat = 900
        let height: CGFloat = 650
        let contentWidth = width - sidebarWidth - 1

        // Sidebar (static)
        let sidebar = ViewNode.vstack(alignment: .leading, spacing: 0, children: [
            .text("Fonts", fontSize: 11, color: .secondary),
            .text("All Fonts", fontSize: 13, color: .primary),
            .spacer(minLength: 0),
        ]).frame(width: sidebarWidth, height: height)

        // Font cards
        let cards: [ViewNode] = families.map { family in
            let selected = state.selectedFamily == family
            let bgColor = selected
                ? Color(red: 0.04, green: 0.52, blue: 1.0, opacity: 0.2)
                : Color(red: 1.0, green: 1.0, blue: 1.0)
            return ViewNode.vstack(alignment: .center, spacing: 4, children: [
                .zstack(children: [
                    .roundedRect(width: nil, height: nil, radius: 8, fill: bgColor),
                    .text("Aa", fontSize: 40, color: .primary),
                ]).frame(width: cardSize, height: cardSize - 30),
                .text(family, fontSize: 10, color: .primary),
            ]).frame(width: cardSize)
        }

        let gridRow = ViewNode.hstack(alignment: .top, spacing: 16, children: cards)
        let grid = ViewNode.vstack(alignment: .leading, spacing: 0, children: [
            .text("All Fonts", fontSize: 16, color: .primary),
            gridRow,
        ]).frame(width: contentWidth, height: height)

        // Content area: ZStack with grid + optional detail
        var zstackChildren: [ViewNode] = [
            .opacity(state.detailFamily == nil ? 1.0 : 0.0, child: grid)
        ]
        if let detail = state.detailFamily {
            let detailView = ViewNode.vstack(alignment: .leading, spacing: 0, children: [
                .text(detail, fontSize: 16, color: .primary),
                .text("A B C D E F", fontSize: 32, color: .primary),
            ]).frame(width: contentWidth, height: height)
            zstackChildren.append(detailView)
        }
        let content = ViewNode.zstack(children: zstackChildren)

        let divider = ViewNode.rect(width: 1, height: nil, fill: Color(red: 0, green: 0, blue: 0, opacity: 0.08))

        return ViewNode.hstack(alignment: .top, spacing: 0, children: [sidebar, divider, content])
    }

    let frame = LayoutFrame(x: 0, y: 0, width: 900, height: 650)

    // === Frame 1: no selection ===
    let tree1 = buildTree()
    let layout1 = Layout.layout(tree1, in: frame)
    let cmds1 = CommandFlattener.flatten(layout1)

    // === Tap: select Iosevka ===
    state.selectedFamily = "Iosevka"
    state.detailFamily = "Iosevka"

    // === Frame 2: Iosevka selected ===
    cache.swapFrames()
    let tree2 = buildTree()

    // The tree MUST be different
    #expect(tree1 != tree2, "View trees should differ after state mutation")

    let layout2 = Layout.layout(tree2, in: frame)
    let cmds2 = CommandFlattener.flatten(layout2)

    // The render commands MUST be different
    #expect(cmds1 != cmds2, "Render commands should differ after state mutation (LayoutCache enabled)")

    // Detail text should appear in frame 2 commands
    let hasDetail = cmds2.contains(where: { cmd in
        if case .text(let content, _, _, _, _, _) = cmd.kind, content == "Iosevka" { return true }
        return false
    })
    #expect(hasDetail, "Frame 2 should contain the detail view text 'Iosevka'")

    // Cache should have hits (sidebar was unchanged)
    #expect(cache.hitsThisFrame > 0, "Cache should hit on unchanged sidebar")
}

/// The actual bug: GeometryReader(id: 0) ViewNode is identical across frames,
/// so LayoutCache returned stale results for the PARENT ZStack containing it.
/// The containsDynamic flag prevents caching ancestors of dynamic nodes.
@Test @MainActor func geometryReaderPreventsParentCaching() {
    let cache = LayoutCache.shared
    cache.clear()
    GeometryReaderRegistry.shared.clear()
    StateGraph.shared.clear()

    var selectedFamily: String? = nil
    let frame = LayoutFrame(x: 0, y: 0, width: 900, height: 650)

    // Build two frames where content changes inside a GeometryReader
    func buildFrame() -> ViewNode {
        // Register a GeometryReader closure that reads `selectedFamily`
        let grId = GeometryReaderRegistry.shared.register { _ in
            let bgColor = selectedFamily != nil
                ? Color(red: 0.04, green: 0.52, blue: 1.0, opacity: 0.2)
                : Color(red: 1.0, green: 1.0, blue: 1.0)
            return ViewNode.vstack(alignment: .leading, spacing: 0, children: [
                .roundedRect(width: 120, height: 90, radius: 8, fill: bgColor),
                .text(selectedFamily ?? "None", fontSize: 14, color: .primary),
            ])
        }
        // Wrap in a ZStack with background (matches App.swift: .background(surface))
        return ViewNode.zstack(children: [
            .rect(width: nil, height: nil, fill: Color(white: 0.95)),
            .geometryReader(id: grId),
        ])
    }

    // Frame 1: no selection
    GeometryReaderRegistry.shared.clear()
    let tree1 = buildFrame()
    let layout1 = Layout.layout(tree1, in: frame)
    let cmds1 = CommandFlattener.flatten(layout1)

    // Frame 2: selection changed
    selectedFamily = "Iosevka"
    cache.swapFrames()
    GeometryReaderRegistry.shared.clear()
    let tree2 = buildFrame()

    // The ViewNode trees look IDENTICAL (geometryReader(id: 0) both times)
    #expect(tree1 == tree2, "ViewNode trees should be identical (geometryReader stores only ID)")

    let layout2 = Layout.layout(tree2, in: frame)
    let cmds2 = CommandFlattener.flatten(layout2)

    // Despite identical ViewNodes, the render commands MUST differ
    #expect(cmds1 != cmds2, "Render commands must differ — GeometryReader content changed")
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
