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
        windowManager.onWindowClosed = { [appManager] wmWindowId in
            appManager.closeWindow(wmWindowId: wmWindowId)
        }
    }

    func compositeFrame(width: CGFloat, height: CGFloat) -> [SurfaceFrame] {
        GeometryReaderRegistry.shared.clear()
        TapRegistry.shared.clear()

        windowManager.screenWidth = width
        windowManager.screenHeight = height

        appManager.processLaunchQueue(windowManager: windowManager, animationManager: animationManager)

        var frames: [SurfaceFrame] = []

        // Desktop background (wallpaper rendered by engine)
        frames.append(SurfaceFrame(
            desc: SurfaceDesc(surfaceId: desktopSurfaceId, x: 0, y: 0, width: Float(width), height: Float(height), cornerRadius: 0, opacity: 1),
            commands: [.wallpaper(x: 0, y: 0, w: Float(width), h: Float(height))],
            pixelData: nil,
            iosurfaceId: 0
        ))

        // Pre-session: only wallpaper + LoginWindow overlay
        if !appManager.sessionStarted {
            frames.append(contentsOf: appManager.overlaySurfaces(
                screenWidth: width, screenHeight: height, windowSurfaceBase: windowSurfaceBase,             ))
            appManager.requestFrames()
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

            // App content: either from shared memory (app-side rendered) or IPC commands
            // Check if app uses IOSurface-backed rendering
            let iosurfaceId = appManager.iosurfaceId(for: window.id)
            let hasIOSurface = iosurfaceId != 0

            if !hasIOSurface {
                // Compositor-rendered: insert IPC commands into chrome
                let ipcCommands = appManager.commands(for: window.id)
                if !ipcCommands.isEmpty {
                    let chromeStartIdx = windowCommands.firstIndex(where: {
                        if case .pushClip = $0 { return true }
                        return false
                    }) ?? 1
                    let contentCommands = ipcCommands.map { Bridge.offsetIpcCommand($0, dy: Float(WindowChrome.titleBarHeight)) }
                    windowCommands.insert(contentsOf: contentCommands, at: chromeStartIdx)
                }
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

            if hasIOSurface {
                // App-side rendered: chrome + content as separate surfaces
                let contentSurfaceId = surfaceId + 50000
                let titleBarH = Float(WindowChrome.titleBarHeight)
                let contentH = Float(frameH) - titleBarH

                // Chrome surface first (back)
                frames.append(SurfaceFrame(
                    desc: SurfaceDesc(
                        surfaceId: surfaceId,
                        x: Float(frameX), y: Float(frameY),
                        width: Float(frameW), height: Float(frameH),
                        cornerRadius: Float(radius),
                        opacity: Float(frameOpacity)
                    ),
                    commands: windowCommands,
                    pixelData: nil,
                    iosurfaceId: 0
                ))

                // Content surface on top — IOSurface (zero-copy)
                frames.append(SurfaceFrame(
                    desc: SurfaceDesc(
                        surfaceId: contentSurfaceId,
                        x: Float(frameX), y: Float(frameY) + titleBarH,
                        width: Float(frameW), height: contentH,
                        cornerRadius: 0,
                        opacity: Float(frameOpacity)
                    ),
                    commands: [],
                    pixelData: nil,
                    iosurfaceId: iosurfaceId
                ))
            } else {
                // Compositor-rendered: single surface with chrome + content
                frames.append(SurfaceFrame(
                    desc: SurfaceDesc(
                        surfaceId: surfaceId,
                        x: Float(frameX), y: Float(frameY),
                        width: Float(frameW), height: Float(frameH),
                        cornerRadius: Float(radius),
                        opacity: Float(frameOpacity)
                    ),
                    commands: windowCommands,
                    pixelData: nil,
                    iosurfaceId: 0
                ))
            }

            // Sheet surfaces: backdrop + sheet panel (separate from parent window)
            if let sheetSize = appManager.sheetSize(for: window.id) {
                let parentX = Float(frameX)
                let parentY = Float(frameY)
                let parentW = Float(frameW)
                let parentH = Float(frameH)

                // Backdrop surface — full parent size, semi-transparent black
                let backdropId = windowSurfaceBase + window.id + 20000
                let backdropCommands: [RenderCommand] = [
                    .rect(x: 0, y: 0, w: parentW, h: parentH,
                           color: RgbaColor(r: 0, g: 0, b: 0, a: 0.3))
                ]
                frames.append(SurfaceFrame(
                    desc: SurfaceDesc(
                        surfaceId: backdropId,
                        x: parentX, y: parentY,
                        width: parentW, height: parentH,
                        cornerRadius: 0, opacity: 1
                    ),
                    commands: backdropCommands,
                    pixelData: nil,
                    iosurfaceId: 0
                ))

                // Sheet surface — centered over parent
                let sheetId = windowSurfaceBase + window.id + 30000
                let sheetW = sheetSize.width
                let sheetH = sheetSize.height
                let sheetX = parentX + (parentW - sheetW) / 2
                let sheetY = parentY + (parentH - sheetH) / 3 // Apple positions sheets in upper third
                let sheetIpcCommands = appManager.sheetCommands(for: window.id)
                let sheetEngineCommands = sheetIpcCommands.map { Bridge.offsetIpcCommand($0, dy: 0) }
                frames.append(SurfaceFrame(
                    desc: SurfaceDesc(
                        surfaceId: sheetId,
                        x: sheetX, y: sheetY,
                        width: sheetW, height: sheetH,
                        cornerRadius: 12, opacity: 1
                    ),
                    commands: sheetEngineCommands,
                    pixelData: nil,
                    iosurfaceId: 0
                ))
            }
        }

        // 3. Overlay surfaces (dock, menubar)
        frames.append(contentsOf: appManager.overlaySurfaces(
            screenWidth: width, screenHeight: height, windowSurfaceBase: windowSurfaceBase,         ))

        // Send state updates to dock and menubar
        let minimizedInfos = windowManager.minimizedWindows.map {
            MinimizedWindowInfo(windowId: $0.id, appId: $0.appId, title: $0.title)
        }
        appManager.sendSystemState(mouseX: CGFloat(mouseX), mouseY: CGFloat(mouseY), minimizedWindows: minimizedInfos, focusedWmWindowId: windowManager.focusedWindowId)

        // Request frames for NEXT render cycle (double-buffered).
        // Apps respond asynchronously — we use their previous response for this frame.
        appManager.requestFrames()

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

    func handleScroll(deltaX: Double, deltaY: Double) {
        // Route scroll to the focused window's app
        if let focusedId = windowManager.focusedWindowId {
            appManager.sendScroll(wmWindowId: focusedId, deltaX: Float(deltaX), deltaY: Float(deltaY))
        }
    }

    /// Current dark mode state.
    private var isDarkMode = false

    /// Toggle dark mode and broadcast to all apps.
    func toggleDarkMode() {
        isDarkMode.toggle()
        appManager.broadcastColorScheme(dark: isDarkMode)
    }

    /// Set dark mode explicitly.
    func setDarkMode(_ dark: Bool) {
        isDarkMode = dark
        appManager.broadcastColorScheme(dark: dark)
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
        logErr("Wallpaper path: \(result.isEmpty ? "(none)" : result)\n")
        return result
    }
}
