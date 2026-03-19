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
    wm.focus(id: id1)
    #expect(wm.windows.last?.id == id1)
    #expect(wm.focusedWindowId == id1)
}

@Test func hitTestReturnsTopmostWindow() {
    let wm = WindowManager()
    let _ = wm.open(appId: "a", title: "A", x: 0, y: 0, width: 400, height: 300)
    let id2 = wm.open(appId: "b", title: "B", x: 50, y: 50, width: 400, height: 300)
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
    #expect(wm.windows[0].x == 200)
    #expect(wm.windows[0].y == 200)
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
    let hit = wm.hitsCloseButton(windowId: id, x: WindowChrome.buttonInsetX + 6, y: WindowChrome.buttonInsetY + 6)
    #expect(hit)
    let miss = wm.hitsCloseButton(windowId: id, x: 300, y: 150)
    #expect(!miss)
}

// MARK: - Minimize

@Test func minimizeHidesWindow() {
    let wm = WindowManager()
    let id = wm.open(appId: "test", title: "Test", x: 0, y: 0, width: 400, height: 300)
    wm.minimize(id: id)
    #expect(wm.windows[0].isMinimized)
    #expect(!wm.windows[0].isVisible)
    #expect(wm.focusedWindowId == nil)
}

@Test func unminimizeRestoresWindow() {
    let wm = WindowManager()
    let id = wm.open(appId: "test", title: "Test", x: 100, y: 100, width: 400, height: 300)
    wm.minimize(id: id)
    wm.unminimize(id: id)
    #expect(!wm.windows[0].isMinimized)
    #expect(wm.windows[0].isVisible)
    #expect(wm.focusedWindowId == id)
}

@Test func minimizedWindowNotHitTestable() {
    let wm = WindowManager()
    let _ = wm.open(appId: "test", title: "Test", x: 0, y: 0, width: 400, height: 300)
    wm.minimize(id: 1)
    let hit = wm.windowAt(x: 200, y: 150)
    #expect(hit == nil)
}

// MARK: - Zoom (maximize)

@Test func zoomMaximizes() {
    let wm = WindowManager()
    wm.screenWidth = 1280
    wm.screenHeight = 800
    let id = wm.open(appId: "test", title: "Test", x: 100, y: 100, width: 400, height: 300)
    wm.zoom(id: id)
    #expect(wm.windows[0].isMaximized)
    #expect(wm.windows[0].x == 0)
    #expect(wm.windows[0].y == WindowChrome.menuBarHeight)
    #expect(wm.windows[0].width == 1280)
    #expect(wm.windows[0].height == 800 - WindowChrome.menuBarHeight)
}

@Test func zoomRestores() {
    let wm = WindowManager()
    wm.screenWidth = 1280
    wm.screenHeight = 800
    let id = wm.open(appId: "test", title: "Test", x: 100, y: 100, width: 400, height: 300)
    wm.zoom(id: id) // maximize
    wm.zoom(id: id) // restore
    #expect(!wm.windows[0].isMaximized)
    #expect(wm.windows[0].x == 100)
    #expect(wm.windows[0].y == 100)
    #expect(wm.windows[0].width == 400)
    #expect(wm.windows[0].height == 300)
}

@Test func dragUnmaximizes() {
    let wm = WindowManager()
    wm.screenWidth = 1280
    wm.screenHeight = 800
    let id = wm.open(appId: "test", title: "Test", x: 100, y: 100, width: 400, height: 300)
    wm.zoom(id: id)
    #expect(wm.windows[0].isMaximized)
    // Drag from maximized state — should unmaximize
    wm.beginDrag(windowId: id, mouseX: 640, mouseY: 19)
    #expect(!wm.windows.last!.isMaximized)
    #expect(wm.windows.last!.width == 400) // restored size
}

// MARK: - Traffic light hit test

@Test func trafficLightHitTestClose() {
    let wm = WindowManager()
    let id = wm.open(appId: "test", title: "Test", x: 0, y: 0, width: 400, height: 300)
    let closeX = WindowChrome.buttonInsetX + WindowChrome.buttonSize / 2
    let btnY = WindowChrome.buttonInsetY + WindowChrome.buttonSize / 2
    let result = wm.hitTestTrafficLight(windowId: id, x: closeX, y: btnY)
    #expect(result == .close)
}

@Test func trafficLightHitTestMinimize() {
    let wm = WindowManager()
    let id = wm.open(appId: "test", title: "Test", x: 0, y: 0, width: 400, height: 300)
    let minimizeX = WindowChrome.buttonInsetX + WindowChrome.buttonSize / 2 + WindowChrome.buttonSize + WindowChrome.buttonSpacing
    let btnY = WindowChrome.buttonInsetY + WindowChrome.buttonSize / 2
    let result = wm.hitTestTrafficLight(windowId: id, x: minimizeX, y: btnY)
    #expect(result == .minimize)
}

@Test func trafficLightHitTestZoom() {
    let wm = WindowManager()
    let id = wm.open(appId: "test", title: "Test", x: 0, y: 0, width: 400, height: 300)
    let zoomX = WindowChrome.buttonInsetX + WindowChrome.buttonSize / 2 + (WindowChrome.buttonSize + WindowChrome.buttonSpacing) * 2
    let btnY = WindowChrome.buttonInsetY + WindowChrome.buttonSize / 2
    let result = wm.hitTestTrafficLight(windowId: id, x: zoomX, y: btnY)
    #expect(result == .zoom)
}

@Test func trafficLightMissesInContent() {
    let wm = WindowManager()
    let id = wm.open(appId: "test", title: "Test", x: 0, y: 0, width: 400, height: 300)
    let result = wm.hitTestTrafficLight(windowId: id, x: 200, y: 150)
    #expect(result == nil)
}

@Test func minimizedWindowsListedSeparately() {
    let wm = WindowManager()
    let _ = wm.open(appId: "a", title: "A", x: 0, y: 0, width: 400, height: 300)
    let id2 = wm.open(appId: "b", title: "B", x: 50, y: 50, width: 400, height: 300)
    wm.minimize(id: id2)
    #expect(wm.minimizedWindows.count == 1)
    #expect(wm.minimizedWindows[0].id == id2)
}
