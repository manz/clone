import Testing
@testable import DesktopKit

let screenWidth: Float = 1280
let screenHeight: Float = 800

// mouseY at the dock zone (near bottom)
let dockY: Float = 780

@Test func dockMagnificationAtCenter() {
    let items = (0..<7).map { _ in
        Dock.DockItem(appId: "test", name: "App", color: .systemBlue)
    }
    let sizes = Dock.magnifiedSizes(
        mouseX: 640, mouseY: dockY,
        items: items, screenWidth: screenWidth, screenHeight: screenHeight
    )
    #expect(sizes.count == 7)

    let maxSize = sizes.max()!
    #expect(maxSize > Dock.baseIconSize)
    #expect(maxSize <= Dock.baseIconSize * Dock.maxScale)
}

@Test func dockMagnificationFarAwayX() {
    let items = [Dock.DockItem(appId: "test", name: "App", color: .systemBlue)]
    let sizes = Dock.magnifiedSizes(
        mouseX: 0, mouseY: dockY,
        items: items, screenWidth: screenWidth, screenHeight: screenHeight
    )
    // Icon centered at ~640 — X distance > influenceRadius
    #expect(sizes[0] == Dock.baseIconSize)
}

@Test func dockMagnificationFarAwayY() {
    let items = (0..<7).map { _ in
        Dock.DockItem(appId: "test", name: "App", color: .systemBlue)
    }
    // Mouse at top of screen — should NOT magnify
    let sizes = Dock.magnifiedSizes(
        mouseX: 640, mouseY: 100,
        items: items, screenWidth: screenWidth, screenHeight: screenHeight
    )
    for size in sizes {
        #expect(size == Dock.baseIconSize)
    }
}

@Test func dockMagnificationSymmetric() {
    let items = (0..<5).map { _ in
        Dock.DockItem(appId: "test", name: "App", color: .systemBlue)
    }
    let sw: Float = 1000
    let leftSizes = Dock.magnifiedSizes(
        mouseX: 450, mouseY: dockY,
        items: items, screenWidth: sw, screenHeight: screenHeight
    )
    let rightSizes = Dock.magnifiedSizes(
        mouseX: 550, mouseY: dockY,
        items: items, screenWidth: sw, screenHeight: screenHeight
    )
    for i in 0..<items.count {
        let mirrorIdx = items.count - 1 - i
        #expect(abs(leftSizes[i] - rightSizes[mirrorIdx]) < 0.01,
                "Symmetry broken at index \(i)")
    }
}

@Test func dockRectIsBottomCentered() {
    let items = Dock.defaultItems
    let rect = Dock.dockRect(items: items, screenWidth: screenWidth, screenHeight: screenHeight)
    #expect(rect.y + rect.h == screenHeight)
    #expect(rect.x > 0)
    #expect(rect.x + rect.w < screenWidth)
}

@Test func dockProducesValidViewTree() {
    let dock = Dock(mouseX: 640, mouseY: dockY, screenWidth: screenWidth, screenHeight: screenHeight)
    let tree = dock.body()
    if case .zstack(let children) = tree {
        #expect(children.count == 2)
    } else {
        Issue.record("Expected zstack from Dock.body()")
    }
}

@Test func dockItemCount() {
    #expect(Dock.defaultItems.count == 7)
}
