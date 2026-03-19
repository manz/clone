import Testing
@testable import DesktopKit

// These tests are in the DesktopKit test target but test the Dock magnification
// math which is pure functions.

@Test func dockMagnificationAtCenter() {
    let items = (0..<7).map { _ in
        Dock.DockItem(name: "App", color: .systemBlue)
    }
    let sizes = Dock.magnifiedSizes(mouseX: 640, items: items, screenWidth: 1280)
    #expect(sizes.count == 7)

    // The icon closest to mouse (center of screen) should be largest
    let maxSize = sizes.max()!
    #expect(maxSize > Dock.baseIconSize)
    #expect(maxSize <= Dock.baseIconSize * Dock.maxScale)
}

@Test func dockMagnificationFarAway() {
    let items = [Dock.DockItem(name: "App", color: .systemBlue)]
    // Mouse far from dock area
    let sizes = Dock.magnifiedSizes(mouseX: 0, items: items, screenWidth: 1280)
    // Icon is centered at ~640 — distance is 640 which is > influenceRadius
    #expect(sizes[0] == Dock.baseIconSize)
}

@Test func dockMagnificationSymmetric() {
    let items = (0..<5).map { _ in
        Dock.DockItem(name: "App", color: .systemBlue)
    }
    let screenWidth: Float = 1000
    let leftSizes = Dock.magnifiedSizes(mouseX: 450, items: items, screenWidth: screenWidth)
    let rightSizes = Dock.magnifiedSizes(mouseX: 550, items: items, screenWidth: screenWidth)
    // Should be mirror-symmetric
    for i in 0..<items.count {
        let mirrorIdx = items.count - 1 - i
        #expect(abs(leftSizes[i] - rightSizes[mirrorIdx]) < 0.01,
                "Symmetry broken at index \(i)")
    }
}

@Test func dockProducesValidViewTree() {
    let dock = Dock(mouseX: 640, screenWidth: 1280, screenHeight: 800)
    let tree = dock.body()
    if case .zstack(let children) = tree {
        #expect(children.count == 2) // background + icon hstack
    } else {
        Issue.record("Expected zstack from Dock.body()")
    }
}

@Test func dockItemCount() {
    #expect(Dock.defaultItems.count == 7)
}
