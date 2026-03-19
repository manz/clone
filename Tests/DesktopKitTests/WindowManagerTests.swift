import Testing
@testable import DesktopKit

@Test func openWindowAssignsId() {
    let wm = WindowManager()
    let id = wm.open(appId: "test", title: "Test", x: 100, y: 100, width: 400, height: 300)
    #expect(id == 1)
    #expect(wm.windows.count == 1)
    #expect(wm.focusedWindowId == id)
}

@Test func openMultipleWindows() {
    let wm = WindowManager()
    let id1 = wm.open(appId: "a", title: "A", x: 0, y: 0, width: 400, height: 300)
    let id2 = wm.open(appId: "b", title: "B", x: 50, y: 50, width: 400, height: 300)
    #expect(wm.windows.count == 2)
    #expect(id1 != id2)
    // Last opened is focused
    #expect(wm.focusedWindowId == id2)
}

@Test func closeWindow() {
    let wm = WindowManager()
    let id = wm.open(appId: "test", title: "Test", x: 0, y: 0, width: 400, height: 300)
    wm.close(id: id)
    #expect(wm.windows.isEmpty)
    #expect(wm.focusedWindowId == nil)
}

@Test func closeTransfersFocus() {
    let wm = WindowManager()
    let id1 = wm.open(appId: "a", title: "A", x: 0, y: 0, width: 400, height: 300)
    let _ = wm.open(appId: "b", title: "B", x: 50, y: 50, width: 400, height: 300)
    wm.close(id: wm.focusedWindowId!)
    #expect(wm.focusedWindowId == id1)
}

@Test func focusBringsToFront() {
    let wm = WindowManager()
    let id1 = wm.open(appId: "a", title: "A", x: 0, y: 0, width: 400, height: 300)
    let _ = wm.open(appId: "b", title: "B", x: 50, y: 50, width: 400, height: 300)
    // id1 is at index 0 (behind), focus brings it to front
    wm.focus(id: id1)
    #expect(wm.windows.last?.id == id1)
    #expect(wm.focusedWindowId == id1)
}

@Test func hitTestReturnsTopmostWindow() {
    let wm = WindowManager()
    let _ = wm.open(appId: "a", title: "A", x: 0, y: 0, width: 400, height: 300)
    let id2 = wm.open(appId: "b", title: "B", x: 50, y: 50, width: 400, height: 300)
    // Point (100, 100) is inside both — should return topmost (id2)
    let hit = wm.windowAt(x: 100, y: 100)
    #expect(hit?.id == id2)
}

@Test func hitTestReturnsNilOutside() {
    let wm = WindowManager()
    let _ = wm.open(appId: "a", title: "A", x: 100, y: 100, width: 200, height: 200)
    let hit = wm.windowAt(x: 50, y: 50)
    #expect(hit == nil)
}

@Test func dragMovesWindow() {
    let wm = WindowManager()
    let id = wm.open(appId: "test", title: "Test", x: 100, y: 100, width: 400, height: 300)
    wm.beginDrag(windowId: id, mouseX: 200, mouseY: 110)
    #expect(wm.isDragging)
    wm.updateDrag(mouseX: 300, mouseY: 210)
    #expect(wm.windows[0].x == 200) // moved 100px right
    #expect(wm.windows[0].y == 200) // moved 100px down
    wm.endDrag()
    #expect(!wm.isDragging)
}

@Test func renderProducesViewNodes() {
    let wm = WindowManager()
    let _ = wm.open(appId: "test", title: "Test", x: 100, y: 100, width: 400, height: 300)
    let nodes = wm.render { _ in
        Text("Hello").fontSize(14)
    }
    #expect(nodes.count == 1)
}

@Test func closeButtonHitTest() {
    let wm = WindowManager()
    let id = wm.open(appId: "test", title: "Test", x: 0, y: 0, width: 400, height: 300)
    // Close button is near top-left
    let hit = wm.hitsCloseButton(windowId: id, x: WindowChrome.buttonInsetX + 6, y: WindowChrome.buttonInsetY + 6)
    #expect(hit)
    // Far from button
    let miss = wm.hitsCloseButton(windowId: id, x: 300, y: 150)
    #expect(!miss)
}
