import Foundation
import Testing
@testable import SwiftUI

@Test @MainActor func tabViewRendersSelectedContent() {
    TapRegistry.shared.clear()

    var selected = "b"
    let binding = Binding(get: { selected }, set: { selected = $0 })

    let tabView = TabView(selection: binding) {
        Tab("Tab A", systemImage: "star", value: "a") { Text("Content A") }
        Tab("Tab B", systemImage: "gear", value: "b") { Text("Content B") }
    }

    let node = tabView._nodeRepresentation
    // Should be a vstack: [tabBar, separator, content]
    guard case .vstack(_, _, let children) = node else {
        Issue.record("Expected vstack, got \(node)")
        return
    }
    #expect(children.count == 3, "Tab bar + separator + content")

    // Content (3rd child) should be the selected tab's content
    let content = children[2]
    if case .text(let text, _, _, _) = content {
        #expect(text == "Content B")
    } else {
        Issue.record("Expected text 'Content B' for selected tab, got \(content)")
    }
}

@Test @MainActor func tabViewRendersTabBar() {
    TapRegistry.shared.clear()

    var selected = "a"
    let binding = Binding(get: { selected }, set: { selected = $0 })

    let tabView = TabView(selection: binding) {
        Tab("Tab A", systemImage: "star", value: "a") { Text("A") }
        Tab("Tab B", systemImage: "gear", value: "b") { Text("B") }
    }

    let node = tabView._nodeRepresentation
    guard case .vstack(_, _, let children) = node else {
        Issue.record("Expected vstack")
        return
    }

    // First child should be the tab bar hstack
    if case .hstack = children[0] {
        // good
    } else {
        Issue.record("Expected hstack tab bar as first child, got \(children[0])")
    }
}

@Test @MainActor func tabViewTapChangesSelection() {
    TapRegistry.shared.clear()

    var selected = "a"
    let binding = Binding(get: { selected }, set: { selected = $0 })

    let tabView = TabView(selection: binding) {
        Tab("Tab A", systemImage: "star", value: "a") { Text("A") }
        Tab("Tab B", systemImage: "gear", value: "b") { Text("B") }
    }

    let node = tabView._nodeRepresentation
    guard case .vstack(_, _, let children) = node else { return }
    guard case .hstack(_, _, let tabButtons) = children[0] else { return }

    // Second tab button should have a tap handler
    // Find the onTap node in the second button
    func findTapId(_ node: ViewNode) -> UInt64? {
        if case .onTap(let id, _) = node { return id }
        return nil
    }

    if let tapId = findTapId(tabButtons[1]) {
        TapRegistry.shared.fire(id: tapId)
        #expect(selected == "b", "Tapping tab B should update selection binding")
    } else {
        Issue.record("Expected onTap on second tab button")
    }
}

@Test @MainActor func tabViewEmptyReturnsEmpty() {
    TapRegistry.shared.clear()

    // Construct directly via internal memberwise init (accessible via @testable)
    let tabView = TabView<String, TabContentBuilder<String>.TabGroup>(
        entries: [],
        selection: nil
    )

    let node = tabView._nodeRepresentation
    if case .empty = node {
        // good
    } else {
        Issue.record("Expected .empty for tabview with no entries, got \(node)")
    }
}

@Test @MainActor func tabViewUntypedWrapsContentAsSingleEntry() {
    TapRegistry.shared.clear()

    let tabView = TabView {
        Text("First")
        Text("Second")
    }

    // Untyped init wraps all content as a single entry with index 0
    // (ViewBuilder returns TupleView, not [ViewNode])
    #expect(tabView.entries.count == 1)
    #expect(tabView.entries[0].value == AnyHashable(0))
    #expect(tabView.entries[0].title == "Tab")
}

@Test @MainActor func tabViewSeparatorBetweenBarAndContent() {
    TapRegistry.shared.clear()

    var selected = "a"
    let binding = Binding(get: { selected }, set: { selected = $0 })

    let tabView = TabView(selection: binding) {
        Tab("Tab A", systemImage: "star", value: "a") { Text("A") }
    }

    let node = tabView._nodeRepresentation
    guard case .vstack(_, _, let children) = node else { return }

    // Second child should be the separator rect
    if case .rect(_, let height, _) = children[1] {
        #expect(height == 1, "Separator should be 1pt tall")
    } else {
        Issue.record("Expected rect separator as second child")
    }
}
