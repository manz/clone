import Foundation
import Testing
@testable import SwiftUI

@Test @MainActor func twoColumnCreatesHStack() {
    let view = NavigationSplitView(
        sidebar: { Text("Sidebar") },
        detail: { Text("Detail") }
    )
    let node = view._nodeRepresentation
    guard case .hstack(_, _, let children) = node else {
        Issue.record("Expected hstack, got \(node)")
        return
    }
    // framed sidebar + divider rect + clipped detail vstack + spacer
    #expect(children.count == 3)
}

@Test @MainActor func sidebarWidthApplied() {
    let view = NavigationSplitView(
        sidebarWidth: 300,
        sidebar: { Text("Sidebar") },
        detail: { Text("Detail") }
    )
    guard case .hstack(_, _, let children) = view._nodeRepresentation else { return }
    if case .frame(let w, _, _) = children[0] {
        #expect(w == 300)
    } else {
        Issue.record("Expected .frame as first child, got \(children[0])")
    }
}

@Test @MainActor func defaultSidebarWidthIs220() {
    let view = NavigationSplitView(
        sidebar: { Text("Sidebar") },
        detail: { Text("Detail") }
    )
    guard case .hstack(_, _, let children) = view._nodeRepresentation else { return }
    if case .frame(let w, _, _) = children[0] {
        #expect(w == 220)
    } else {
        Issue.record("Expected .frame as first child")
    }
}

@Test @MainActor func threeColumnCreatesCorrectStructure() {
    let view = NavigationSplitView(
        sidebar: { Text("Sidebar") },
        content: { Text("Content") },
        detail: { Text("Detail") }
    )
    guard case .hstack(_, _, let children) = view._nodeRepresentation else {
        Issue.record("Expected hstack")
        return
    }
    // framed sidebar + divider + content vstack + divider + detail vstack
    #expect(children.count == 5)
}

@Test @MainActor func columnVisibilityBindingAccepted() {
    var visibility: NavigationSplitViewVisibility = .all
    let binding = Binding(get: { visibility }, set: { visibility = $0 })

    let view = NavigationSplitView(
        columnVisibility: binding,
        sidebar: { Text("Sidebar") },
        detail: { Text("Detail") }
    )
    // Should produce same structure as two-column
    guard case .hstack(_, _, let children) = view._nodeRepresentation else {
        Issue.record("Expected hstack")
        return
    }
    #expect(children.count == 3)
}

@Test @MainActor func sidebarLayoutIntegration() {
    let view = NavigationSplitView(
        sidebarWidth: 250,
        sidebar: { Text("Sidebar") },
        detail: { Text("Detail") }
    )
    let layoutNode = Layout.layout(
        view._nodeRepresentation,
        in: LayoutFrame(x: 0, y: 0, width: 800, height: 600)
    )
    // First child should be the framed sidebar with width 250
    let sidebarChild = layoutNode.children[0]
    #expect(sidebarChild.frame.width == 250)
}
