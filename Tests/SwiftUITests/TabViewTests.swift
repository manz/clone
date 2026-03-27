import Foundation
import Testing
@testable import SwiftUI

@Test @MainActor func tabViewRendersSelectedContent() {
    TapRegistry.shared.clear()
    WindowState.shared.update(width: 600, height: 400)

    var selected = "b"
    let binding = Binding(get: { selected }, set: { selected = $0 })

    let tabView = TabView(selection: binding) {
        Tab("Tab A", systemImage: "star", value: "a") { Text("Content A") }
        Tab("Tab B", systemImage: "gear", value: "b") { Text("Content B") }
    }

    let node = tabView._nodeRepresentation
    // Tab bar now goes to toolbar — _nodeRepresentation returns just the selected content
    if case .text(let text, _, _, _, _) = node {
        #expect(text == "Content B")
    } else {
        Issue.record("Expected text 'Content B' for selected tab, got \(node)")
    }
}

@Test @MainActor func tabViewRendersTabBar() {
    TapRegistry.shared.clear()
    WindowState.shared.update(width: 600, height: 400)

    var selected = "a"
    let binding = Binding(get: { selected }, set: { selected = $0 })

    let tv = TabView(selection: binding) {
        Tab("Tab A", systemImage: "star", value: "a") { Text("A") }
        Tab("Tab B", systemImage: "gear", value: "b") { Text("B") }
    }
    let _ = tv._nodeRepresentation  // triggers toolbar registration

    // Tab bar is registered as a toolbar item
    let tabItems = WindowState.shared.toolbarItems.filter { $0.placement == .principal }
    #expect(!tabItems.isEmpty, "Tab bar should be registered as a toolbar item")
}

@Test @MainActor func tabViewTapChangesSelection() {
    TapRegistry.shared.clear()
    WindowState.shared.update(width: 600, height: 400)

    var selected = "a"
    let binding = Binding(get: { selected }, set: { selected = $0 })

    let tv = TabView(selection: binding) {
        Tab("Tab A", systemImage: "star", value: "a") { Text("A") }
        Tab("Tab B", systemImage: "gear", value: "b") { Text("B") }
    }
    let _ = tv._nodeRepresentation

    // Find the tab bar toolbar item and its tap handlers
    let tabItems = WindowState.shared.toolbarItems.filter { $0.placement == .principal }
    guard let tabBar = tabItems.first else {
        Issue.record("No tab bar toolbar item")
        return
    }

    // Find onTap in the tab bar hstack
    func findTapIds(_ node: ViewNode) -> [UInt64] {
        switch node {
        case .onTap(let id, _): return [id]
        case .hstack(_, _, let children): return children.flatMap { findTapIds($0) }
        case .padding(_, let child): return findTapIds(child)
        default: return []
        }
    }

    let tapIds = findTapIds(tabBar.node)
    #expect(tapIds.count >= 2, "Should have tap handlers for each tab")

    if tapIds.count >= 2 {
        TapRegistry.shared.fire(id: tapIds[1])
        #expect(selected == "b", "Tapping tab B should update selection")
    }
}

@Test @MainActor func tabViewEmptyReturnsEmpty() {
    TapRegistry.shared.clear()
    WindowState.shared.update(width: 600, height: 400)

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
