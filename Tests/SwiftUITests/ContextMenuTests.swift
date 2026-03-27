import Testing
import Foundation
@testable import SwiftUI

@Test @MainActor func contextMenuCreatesNode() {
    let node = _resolve(Text("Right-click me"))
        .contextMenu {
            Button("Copy") {}
            Button("Paste") {}
            Divider()
            Button("Delete") {}
        }

    guard case .contextMenu(let child, let items) = node else {
        Issue.record("Expected .contextMenu, got \(node)")
        return
    }

    // Child is the text
    if case .text(let content, _, _, _, _) = child {
        #expect(content == "Right-click me")
    } else {
        Issue.record("Expected text child")
    }

    // Menu items: 3 buttons + 1 divider = 4 items
    #expect(items.count == 4)
}

@Test @MainActor func contextMenuRegistryOpenClose() {
    ContextMenuRegistry.shared.clear()

    let items: [ViewNode] = [
        _resolve(Button("Cut") {}),
        _resolve(Button("Copy") {}),
    ]

    #expect(ContextMenuRegistry.shared.isOpen == false)

    ContextMenuRegistry.shared.open(items: items, x: 100, y: 200)
    #expect(ContextMenuRegistry.shared.isOpen == true)
    #expect(ContextMenuRegistry.shared.menuItems.count == 2)
    #expect(ContextMenuRegistry.shared.position.x == 100)
    #expect(ContextMenuRegistry.shared.position.y == 200)

    ContextMenuRegistry.shared.close()
    #expect(ContextMenuRegistry.shared.isOpen == false)
}

@Test @MainActor func contextMenuHitTest() {
    // A contextMenu node should be findable via hit test
    let node = ViewNode.contextMenu(
        child: .rect(width: 100, height: 50, fill: .blue),
        menuItems: [.text("Copy", fontSize: 14, color: .primary)]
    )

    let layoutNode = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 200, height: 200))

    // Hit test should find context menu items at the node's location
    let result = layoutNode.hitTestContextMenu(x: 50, y: 25)
    #expect(result != nil)
    #expect(result?.count == 1)
}
