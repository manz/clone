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

/// Where a press was routed — determines where the matching release goes.
@MainActor
enum PressTarget {
    /// Press went to a window's content surface. Local coords recorded on press.
    case window(wmId: UInt64)
    /// Press went to a sheet surface of the given parent window.
    case sheet(parentWmId: UInt64)
    /// Press went to an overlay (dock, menubar, loginWindow) — screen coords.
    case overlay(wmId: UInt64)
    /// Press consumed by compositor chrome (traffic light, title drag, resize,
    /// sheet backdrop, empty desktop). App must NOT receive a release for it.
    case chrome
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
        x: CGFloat, y: CGFloat,
        mouseDown: inout Bool,
        activePress: inout [UInt32: PressTarget],
        windowManager: WindowManager,
        appManager: AppConnectionManager,
        animationManager: AnimationManager
    ) {
        if pressed {
            if button == 0 { mouseDown = true }
            let target = routePress(
                button: button, x: x, y: y,
                windowManager: windowManager,
                appManager: appManager,
                animationManager: animationManager
            )
            activePress[button] = target
        } else {
            if button == 0 { mouseDown = false }

            // End compositor-owned drag/resize regardless of where press was recorded.
            if windowManager.isResizing {
                if let wid = windowManager.resizingWindowId,
                   let w = windowManager.windows.first(where: { $0.id == wid }) {
                    appManager.notifyResize(wmWindowId: wid, window: w)
                }
                windowManager.endResize()
            }
            windowManager.endDrag()

            // Route release to whoever got the press for this button.
            let target = activePress.removeValue(forKey: button) ?? .chrome
            switch target {
            case .window(let wmId):
                guard let w = windowManager.windows.first(where: { $0.id == wmId }) else { return }
                let localX = x - w.x
                let localY = y - w.y
                appManager.sendPointerButton(wmWindowId: wmId, button: button, pressed: false, x: Float(localX), y: Float(localY))
            case .sheet(let parentWmId):
                guard let parent = windowManager.windows.first(where: { $0.id == parentWmId }),
                      let sheetSize = appManager.sheetSize(for: parentWmId) else { return }
                let sheetW = CGFloat(sheetSize.width)
                let sheetH = CGFloat(sheetSize.height)
                let sheetX = parent.x + (parent.width - sheetW) / 2
                let sheetY = parent.y + (parent.height - sheetH) / 3
                let localX = x - sheetX
                let localY = y - sheetY
                appManager.sendSheetPointerButton(wmWindowId: parentWmId, button: button, pressed: false, x: Float(localX), y: Float(localY))
            case .overlay(let wmId):
                appManager.sendPointerButton(wmWindowId: wmId, button: button, pressed: false, x: Float(x), y: Float(y))
            case .chrome:
                break
            }
        }
    }

    /// Resolve where the press should be routed. Dispatches side effects
    /// (begin drag/resize, close window, dismiss popups, send press) and
    /// returns the target so the matching release can be routed to the same place.
    private static func routePress(
        button: UInt32, x: CGFloat, y: CGFloat,
        windowManager: WindowManager,
        appManager: AppConnectionManager,
        animationManager: AnimationManager
    ) -> PressTarget {
        // Left-button resize edges (windows only).
        if button == 0 {
            for window in windowManager.windows.reversed() where window.isVisible && !window.isMinimized && window.role == .window {
                if let edge = windowManager.hitTestResizeEdge(windowId: window.id, x: x, y: y) {
                    windowManager.beginResize(windowId: window.id, edge: edge, mouseX: x, mouseY: y)
                    return .chrome
                }
            }
        }

        // Sheet interception — only if focused window has an active sheet and
        // the click is inside the parent window bounds.
        if let focusedId = windowManager.focusedWindowId,
           let window = windowManager.windows.first(where: { $0.id == focusedId }),
           let sheetSize = appManager.sheetSize(for: focusedId),
           x >= window.x, x < window.x + window.width,
           y >= window.y, y < window.y + window.height {
            let sheetW = CGFloat(sheetSize.width)
            let sheetH = CGFloat(sheetSize.height)
            let sheetX = window.x + (window.width - sheetW) / 2
            let sheetY = window.y + (window.height - sheetH) / 3
            if x >= sheetX, x < sheetX + sheetW, y >= sheetY, y < sheetY + sheetH {
                let localX = x - sheetX
                let localY = y - sheetY
                appManager.sendSheetPointerButton(wmWindowId: focusedId, button: button, pressed: true, x: Float(localX), y: Float(localY))
                return .sheet(parentWmId: focusedId)
            } else {
                appManager.sendSheetBackdropTapped(wmWindowId: focusedId)
                return .chrome
            }
        }

        // Dismiss popups on clicks outside them. Click still propagates to
        // the window behind, matching macOS context-menu dismissal.
        let hitWindow = windowManager.windowAt(x: x, y: y)
        if hitWindow?.role != .popup {
            appManager.dismissAllPopups(windowManager: windowManager)
        }

        guard let window = hitWindow else { return .chrome }

        if window.role == .window {
            if button == 0, let trafficLight = windowManager.hitTestTrafficLight(windowId: window.id, x: x, y: y) {
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
                return .chrome
            }

            if button == 0, window.titleBarContains(px: x, py: y) {
                let wasMaximized = windowManager.windows.first(where: { $0.id == window.id })?.isMaximized ?? false
                windowManager.beginDrag(windowId: window.id, mouseX: x, mouseY: y)
                if wasMaximized, let w = windowManager.windows.first(where: { $0.id == window.id }) {
                    appManager.notifyResize(wmWindowId: window.id, window: w)
                }
                windowManager.focus(id: window.id)
                return .chrome
            }

            let localX = x - window.x
            let localY = y - window.y
            appManager.sendPointerButton(wmWindowId: window.id, button: button, pressed: true, x: Float(localX), y: Float(localY))
            windowManager.focus(id: window.id)
            return .window(wmId: window.id)
        }

        // Overlay (dock, menubar, loginWindow) — fullscreen surface, screen coords.
        appManager.sendPointerButton(wmWindowId: window.id, button: button, pressed: true, x: Float(x), y: Float(y))
        return .overlay(wmId: window.id)
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
