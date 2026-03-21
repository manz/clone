import Foundation
import SwiftUI
import CloneProtocol

/// Orchestrates window management, input routing, chrome rendering, and app lifecycle.
/// This is the "brain" of the compositor — produces SurfaceFrames for the RenderServer.
@MainActor
public final class WindowServer {
    let windowManager = WindowManager()
    let appManager = AppConnectionManager()
    let animationManager = AnimationManager()
    private var mouseX: Double = 0
    private var mouseY: Double = 0
    private var mouseDown = false

    /// Surface IDs: 0 = desktop, 1 = dock, 2 = menubar, 100+ = windows
    private let desktopSurfaceId: UInt64 = 0
    private let windowSurfaceBase: UInt64 = 100

    init() {
        appManager.start()
    }

    func compositeFrame(width: CGFloat, height: CGFloat) -> [SurfaceFrame] {
        GeometryReaderRegistry.shared.clear()
        TapRegistry.shared.clear()

        windowManager.screenWidth = width
        windowManager.screenHeight = height

        appManager.processLaunchQueue(windowManager: windowManager, animationManager: animationManager)
        appManager.requestFrames()

        var frames: [SurfaceFrame] = []

        // Desktop background (wallpaper rendered by engine)
        frames.append(SurfaceFrame(
            desc: SurfaceDesc(surfaceId: desktopSurfaceId, x: 0, y: 0, width: Float(width), height: Float(height), cornerRadius: 0, opacity: 1),
            commands: [.wallpaper(x: 0, y: 0, w: Float(width), h: Float(height))]
        ))

        // Pre-session: only wallpaper + LoginWindow overlay
        if !appManager.sessionStarted {
            frames.append(contentsOf: appManager.overlaySurfaces(
                screenWidth: width, screenHeight: height, windowSurfaceBase: windowSurfaceBase
            ))
            return frames
        }

        appManager.syncNewApps(windowManager: windowManager)
        appManager.syncResizingDimensions(windowManager: windowManager)

        // Tick animations — complete minimize by actually hiding the window
        for (windowId, wasMinimizing) in animationManager.tick() {
            if wasMinimizing {
                windowManager.minimize(id: windowId)
            }
        }

        // Windows — visible + currently animating
        let visibleWindows = windowManager.windows.filter {
            ($0.isVisible && !$0.isMinimized) || animationManager.isAnimating($0.id)
        }
        for window in visibleWindows {
            let surfaceId = windowSurfaceBase + window.id
            let isFocused = window.id == windowManager.focusedWindowId
            let showSymbols = windowManager.hoveredWindowId == window.id && windowManager.hoveringTrafficLights
            let radius: CGFloat = window.isMaximized ? 0 : WindowChrome.cornerRadius

            // Build chrome + content in local coordinates
            var windowCommands = ChromeRenderer.renderWindow(
                width: Float(window.width), height: Float(window.height), radius: Float(radius),
                isFocused: isFocused, isMaximized: window.isMaximized,
                showTrafficLightSymbols: showSymbols, title: window.title
            )

            // Insert app content before chrome (chrome is appended last by ChromeRenderer,
            // but we need content between background and chrome). We insert after the first
            // command (background rect), before the pushClip that starts chrome overlay.
            let ipcCommands = appManager.commands(for: window.id)
            if !ipcCommands.isEmpty {
                // Find the pushClip index (the chrome overlay start)
                let chromeStartIdx = windowCommands.firstIndex(where: {
                    if case .pushClip = $0 { return true }
                    return false
                }) ?? 1
                let contentCommands = ipcCommands.map { Bridge.offsetIpcCommand($0, dy: Float(WindowChrome.titleBarHeight)) }
                windowCommands.insert(contentsOf: contentCommands, at: chromeStartIdx)
            }

            // Apply animation override
            var frameX = window.x
            var frameY = window.y
            var frameW = window.width
            var frameH = window.height
            var frameOpacity: CGFloat = 1.0

            if let (animRect, animOpacity) = animationManager.animatedRect(for: window.id) {
                frameX = animRect.x
                frameY = animRect.y
                frameW = animRect.w
                frameH = animRect.h
                frameOpacity = animOpacity
            }

            frames.append(SurfaceFrame(
                desc: SurfaceDesc(
                    surfaceId: surfaceId,
                    x: Float(frameX), y: Float(frameY),
                    width: Float(frameW), height: Float(frameH),
                    cornerRadius: Float(radius),
                    opacity: Float(frameOpacity)
                ),
                commands: windowCommands
            ))
        }

        // 3. Overlay surfaces (dock, menubar)
        frames.append(contentsOf: appManager.overlaySurfaces(
            screenWidth: width, screenHeight: height, windowSurfaceBase: windowSurfaceBase
        ))

        // Send state updates to dock and menubar
        let minimizedIds = windowManager.minimizedWindows.map(\.appId)
        appManager.sendSystemState(mouseX: CGFloat(mouseX), mouseY: CGFloat(mouseY), minimizedAppIds: minimizedIds, focusedWmWindowId: windowManager.focusedWindowId)

        return frames
    }

    func handlePointerMove(x: Double, y: Double) {
        mouseX = x
        mouseY = y
        InputRouter.routePointerMove(
            x: CGFloat(x), y: CGFloat(y),
            windowManager: windowManager,
            appManager: appManager
        )
    }

    func handlePointerButton(button: UInt32, pressed: Bool) {
        InputRouter.routePointerButton(
            button: button, pressed: pressed,
            x: CGFloat(mouseX), y: CGFloat(mouseY), mouseDown: &mouseDown,
            windowManager: windowManager,
            appManager: appManager,
            animationManager: animationManager
        )
    }

    func handleKey(keycode: UInt32, pressed: Bool) {
        InputRouter.routeKey(
            keycode: keycode, pressed: pressed,
            windowManager: windowManager,
            appManager: appManager
        )
    }

    func handleKeyChar(character: String) {
        InputRouter.routeKeyChar(
            character: character,
            windowManager: windowManager,
            appManager: appManager
        )
    }

    func wallpaperPath() -> String {
        let fm = FileManager.default
        let execURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let projectRoot = execURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let candidates = [
            projectRoot.appendingPathComponent("engine/assets/wallpaper.jpg").path,
            fm.currentDirectoryPath + "/engine/assets/wallpaper.jpg",
        ]
        let result = candidates.first(where: { fm.fileExists(atPath: $0) }) ?? ""
        fputs("Wallpaper path: \(result.isEmpty ? "(none)" : result)\n", stderr)
        return result
    }
}
