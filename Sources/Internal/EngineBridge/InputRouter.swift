import SwiftUI

// MARK: - Winit keycode constants (KeyCode enum discriminants)

enum KeyCode {
    static let keyW: UInt32 = 53
    static let f3: UInt32 = 161
    static let f12: UInt32 = 170
}

/// NSEvent.ModifierFlags bitmask values (matched by engine/src/window.rs).
struct ModifierFlags {
    static let shift: UInt32   = 1 << 17
    static let control: UInt32 = 1 << 18
    static let option: UInt32  = 1 << 19
    static let command: UInt32 = 1 << 20
}

/// Routes pointer and keyboard input to the appropriate window/app.
@MainActor
struct InputRouter {
    static func routePointerMove(
        x: CGFloat, y: CGFloat,
        windowManager: WindowManager,
        appManager: AppConnectionManager
    ) {
        if windowManager.isResizing {
            windowManager.updateResize(mouseX: x, mouseY: y)
            return
        }

        if windowManager.isDragging {
            windowManager.updateDrag(mouseX: x, mouseY: y)
            return
        }

        // Hit test all surfaces (windows + overlays) — unified path
        guard let window = windowManager.windowAt(x: x, y: y) else {
            windowManager.hoveredWindowId = nil
            if windowManager.hoveringTrafficLights {
                windowManager.hoveringTrafficLights = false
                if let focusedId = windowManager.focusedWindowId {
                    appManager.sendTrafficLightHover(wmWindowId: focusedId, isHovered: false)
                }
            }
            return
        }

        windowManager.hoveredWindowId = window.id

        // Traffic light hover (windows only)
        if window.role == .window {
            let prevHover = windowManager.hoveringTrafficLights
            windowManager.hoveringTrafficLights = windowManager.isOverTrafficLights(
                windowId: window.id, x: x, y: y
            )
            if windowManager.hoveringTrafficLights != prevHover {
                appManager.sendTrafficLightHover(wmWindowId: window.id, isHovered: windowManager.hoveringTrafficLights)
            }
        }

        // Overlays render fullscreen — send screen coords. Windows get local coords.
        let sendX: CGFloat, sendY: CGFloat
        if window.isOverlay {
            sendX = x; sendY = y
        } else {
            sendX = x - window.x; sendY = y - window.y
        }
        appManager.sendPointerMove(wmWindowId: window.id, localX: Float(sendX), localY: Float(sendY))
    }

    static func routePointerButton(
        button: UInt32, pressed: Bool,
        x: CGFloat, y: CGFloat, mouseDown: inout Bool,
        windowManager: WindowManager,
        appManager: AppConnectionManager,
        animationManager: AnimationManager
    ) {
        if button == 0 {
            if pressed {
                mouseDown = true

                // Check resize edges first (windows only)
                for window in windowManager.windows.reversed() where window.isVisible && !window.isMinimized && window.role == .window {
                    if let edge = windowManager.hitTestResizeEdge(windowId: window.id, x: x, y: y) {
                        windowManager.beginResize(windowId: window.id, edge: edge, mouseX: x, mouseY: y)
                        return
                    }
                }

                // Sheet click interception — before normal window hit-test
                if let focusedId = windowManager.focusedWindowId,
                   let window = windowManager.windows.first(where: { $0.id == focusedId }),
                   let sheetSize = appManager.sheetSize(for: focusedId) {
                    let parentX = window.x
                    let parentY = window.y
                    let parentW = window.width
                    let parentH = window.height
                    if x >= parentX && x < parentX + parentW && y >= parentY && y < parentY + parentH {
                        let sheetW = CGFloat(sheetSize.width)
                        let sheetH = CGFloat(sheetSize.height)
                        let sheetX = parentX + (parentW - sheetW) / 2
                        let sheetY = parentY + (parentH - sheetH) / 3
                        if x >= sheetX && x < sheetX + sheetW && y >= sheetY && y < sheetY + sheetH {
                            let localX = x - sheetX
                            let localY = y - sheetY
                            appManager.sendSheetPointerButton(wmWindowId: focusedId, button: button, pressed: true, x: Float(localX), y: Float(localY))
                        } else {
                            appManager.sendSheetBackdropTapped(wmWindowId: focusedId)
                        }
                        return
                    }
                }

                // Dismiss popups on any click outside them
                let hitWindow = windowManager.windowAt(x: x, y: y)
                if hitWindow?.role != .popup {
                    appManager.dismissAllPopups(windowManager: windowManager)
                }

                // Unified hit test — windows and overlays
                if let window = hitWindow {
                    if window.role == .window {
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
                            let localY = y - window.y
                            appManager.sendPointerButton(wmWindowId: window.id, button: button, pressed: true, x: Float(localX), y: Float(localY))
                        }

                        windowManager.focus(id: window.id)
                    } else {
                        // Overlay (dock, menubar, loginWindow) — send screen coords (fullscreen surface)
                        appManager.sendPointerButton(wmWindowId: window.id, button: button, pressed: true, x: Float(x), y: Float(y))
                    }
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
                    if window.role == .window {
                        windowManager.focus(id: window.id)
                    }
                    let sx = window.isOverlay ? x : x - window.x
                    let sy = window.isOverlay ? y : y - window.y
                    appManager.sendPointerButton(wmWindowId: window.id, button: button, pressed: true, x: Float(sx), y: Float(sy))
                }
            } else {
                if let focusedId = windowManager.focusedWindowId {
                    appManager.sendPointerButton(wmWindowId: focusedId, button: button, pressed: false, x: 0, y: 0)
                }
            }
        }
    }

    static func routeKey(
        keycode: UInt32, modifiers: UInt32, pressed: Bool,
        windowManager: WindowManager,
        appManager: AppConnectionManager,
        animationManager: AnimationManager
    ) {
        guard pressed else { return }

        // Compositor-level shortcuts — intercepted before forwarding to apps
        switch keycode {
        case KeyCode.f3:
            windowManager.toggleExpose(animationManager: animationManager)
            return
        default:
            break
        }

        // Forward to focused window, or loginWindow pre-session
        let targetId = windowManager.focusedWindowId
            ?? windowManager.windows.first(where: { $0.role == .loginWindow })?.id
        if let id = targetId {
            appManager.sendKey(wmWindowId: id, keycode: keycode, pressed: pressed)
        }
    }

    static func routeKeyChar(
        character: String,
        windowManager: WindowManager,
        appManager: AppConnectionManager
    ) {
        let targetId = windowManager.focusedWindowId
            ?? windowManager.windows.first(where: { $0.role == .loginWindow })?.id
        if let id = targetId {
            appManager.sendKeyChar(wmWindowId: id, character: character)
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
