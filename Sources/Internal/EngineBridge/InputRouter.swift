import SwiftUI

/// Routes pointer and keyboard input to the appropriate window/app.
@MainActor
struct InputRouter {
    static func routePointerMove(
        x: CGFloat, y: CGFloat,
        windowManager: WindowManager,
        appManager: AppConnectionManager
    ) {
        // Pre-session: all input goes to LoginWindow
        if !appManager.sessionStarted {
            appManager.sendToLoginWindow(pointerMove: Float(x), y: Float(y))
            return
        }

        if windowManager.isResizing {
            windowManager.updateResize(mouseX: x, mouseY: y)
            return
        }

        if windowManager.isDragging {
            windowManager.updateDrag(mouseX: x, mouseY: y)
            return
        }

        // Update traffic light hover state
        if let window = windowManager.windowAt(x: x, y: y) {
            windowManager.hoveredWindowId = window.id
            windowManager.hoveringTrafficLights = windowManager.isOverTrafficLights(
                windowId: window.id, x: x, y: y
            )
        } else {
            windowManager.hoveredWindowId = nil
            windowManager.hoveringTrafficLights = false
        }

        // Forward to focused external app
        if let focusedId = windowManager.focusedWindowId,
           let window = windowManager.windows.first(where: { $0.id == focusedId }) {
            let localX = x - window.x
            let localY = y - window.y - WindowChrome.titleBarHeight
            appManager.sendPointerMove(wmWindowId: focusedId, localX: Float(localX), localY: Float(localY))
        }
    }

    static func routePointerButton(
        button: UInt32, pressed: Bool,
        x: CGFloat, y: CGFloat, mouseDown: inout Bool,
        windowManager: WindowManager,
        appManager: AppConnectionManager,
        animationManager: AnimationManager
    ) {
        if !appManager.sessionStarted {
            appManager.sendToLoginWindow(pointerButton: button, pressed: pressed, x: Float(x), y: Float(y))
            return
        }

        if button == 0 {
            if pressed {
                mouseDown = true

                // Check resize edges first
                for window in windowManager.windows.reversed() where window.isVisible && !window.isMinimized {
                    if let edge = windowManager.hitTestResizeEdge(windowId: window.id, x: x, y: y) {
                        windowManager.beginResize(windowId: window.id, edge: edge, mouseX: x, mouseY: y)
                        return
                    }
                }

                // Sheet click interception — before normal window hit-test
                if let focusedId = windowManager.focusedWindowId,
                   let window = windowManager.windows.first(where: { $0.id == focusedId }),
                   let sheetSize = appManager.sheetSize(for: focusedId) {
                    // Check if click is within parent window bounds
                    let parentX = window.x
                    let parentY = window.y
                    let parentW = window.width
                    let parentH = window.height
                    if x >= parentX && x < parentX + parentW && y >= parentY && y < parentY + parentH {
                        // Sheet is centered in the parent
                        let sheetW = CGFloat(sheetSize.width)
                        let sheetH = CGFloat(sheetSize.height)
                        let sheetX = parentX + (parentW - sheetW) / 2
                        let sheetY = parentY + (parentH - sheetH) / 3
                        if x >= sheetX && x < sheetX + sheetW && y >= sheetY && y < sheetY + sheetH {
                            // Click inside sheet — send sheet-local coordinates
                            let localX = x - sheetX
                            let localY = y - sheetY
                            appManager.sendSheetPointerButton(wmWindowId: focusedId, button: button, pressed: true, x: Float(localX), y: Float(localY))
                        } else {
                            // Click on backdrop — dismiss sheet
                            appManager.sendSheetBackdropTapped(wmWindowId: focusedId)
                        }
                        return
                    }
                }

                if let window = windowManager.windowAt(x: x, y: y) {
                    // Traffic light buttons
                    if let trafficLight = windowManager.hitTestTrafficLight(windowId: window.id, x: x, y: y) {
                        switch trafficLight {
                        case .close:
                            windowManager.close(id: window.id)
                        case .minimize:
                            animateMinimize(windowId: window.id, windowManager: windowManager, appManager: appManager, animationManager: animationManager)
                        case .zoom:
                            windowManager.zoom(id: window.id)
                            if let w = windowManager.windows.first(where: { $0.id == window.id }) {
                                appManager.notifyResize(wmWindowId: window.id, window: w)
                            }
                        }
                        appManager.updateFocusedAppName(windowManager: windowManager)
                        return
                    }

                    // Title bar drag
                    if window.titleBarContains(px: x, py: y) {
                        let wasMaximized = windowManager.windows.first(where: { $0.id == window.id })?.isMaximized ?? false
                        windowManager.beginDrag(windowId: window.id, mouseX: x, mouseY: y)
                        if wasMaximized {
                            if let w = windowManager.windows.first(where: { $0.id == window.id }) {
                                appManager.notifyResize(wmWindowId: window.id, window: w)
                            }
                        }
                    } else {
                        let localX = x - window.x
                        let localY = y - window.y - WindowChrome.titleBarHeight
                        appManager.sendPointerButton(wmWindowId: window.id, button: button, pressed: true, x: Float(localX), y: Float(localY))
                    }

                    windowManager.focus(id: window.id)
                    appManager.updateFocusedAppName(windowManager: windowManager)
                } else {
                    // No window hit — forward to overlays
                    appManager.sendPointerButtonToOverlays(button: button, pressed: true, x: Float(x), y: Float(y))
                }
            } else {
                mouseDown = false

                if windowManager.isResizing {
                    if let wid = windowManager.resizingWindowId,
                       let w = windowManager.windows.first(where: { $0.id == wid }) {
                        appManager.notifyResize(wmWindowId: wid, window: w)
                    }
                    windowManager.endResize()
                }
                windowManager.endDrag()

                if let focusedId = windowManager.focusedWindowId {
                    appManager.sendPointerButton(wmWindowId: focusedId, button: button, pressed: false, x: 0, y: 0)
                }
            }
        } else {
            // Non-left buttons
            if pressed {
                if let window = windowManager.windowAt(x: x, y: y) {
                    windowManager.focus(id: window.id)
                    appManager.updateFocusedAppName(windowManager: windowManager)
                    let localX = x - window.x
                    let localY = y - window.y - WindowChrome.titleBarHeight
                    appManager.sendPointerButton(wmWindowId: window.id, button: button, pressed: true, x: Float(localX), y: Float(localY))
                }
            } else {
                if let focusedId = windowManager.focusedWindowId {
                    appManager.sendPointerButton(wmWindowId: focusedId, button: button, pressed: false, x: 0, y: 0)
                }
            }
        }
    }

    static func routeKey(
        keycode: UInt32, pressed: Bool,
        windowManager: WindowManager,
        appManager: AppConnectionManager
    ) {
        if !appManager.sessionStarted {
            appManager.sendToLoginWindow(key: keycode, pressed: pressed)
            return
        }

        guard pressed else { return }

        // Forward to focused external app
        if let focusedId = windowManager.focusedWindowId {
            appManager.sendKey(wmWindowId: focusedId, keycode: keycode, pressed: pressed)
            return
        }

        // Compositor key bindings (only when no external app focused)
        switch keycode {
        case 53: // 'w' — close focused window
            if let id = windowManager.focusedWindowId {
                windowManager.close(id: id)
                appManager.updateFocusedAppName(windowManager: windowManager)
            }
        default:
            break
        }
    }

    static func routeKeyChar(
        character: String,
        windowManager: WindowManager,
        appManager: AppConnectionManager
    ) {
        if !appManager.sessionStarted {
            appManager.sendToLoginWindow(keyChar: character)
            return
        }

        if let focusedId = windowManager.focusedWindowId {
            appManager.sendKeyChar(wmWindowId: focusedId, character: character)
        }
    }

    private static func animateMinimize(windowId: UInt64, windowManager: WindowManager, appManager: AppConnectionManager, animationManager: AnimationManager) {
        guard let window = windowManager.windows.first(where: { $0.id == windowId }) else { return }
        let from = AnimRect(x: window.x, y: window.y, w: window.width, h: window.height)
        let to = Dock.minimizeTargetRect(
            slotIndex: windowManager.minimizedWindows.count,
            pinnedCount: Dock.pinnedAppIds.count,
            unpinnedRunningCount: appManager.unpinnedRunningCount(pinnedAppIds: Dock.pinnedAppIds),
            minimizedCount: windowManager.minimizedWindows.count + 1,
            screenWidth: windowManager.screenWidth,
            screenHeight: windowManager.screenHeight
        )
        animationManager.startMinimize(windowId: windowId, from: from, to: to)
    }
}
