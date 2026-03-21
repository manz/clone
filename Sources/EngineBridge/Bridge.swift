import Foundation
import SwiftUI
import CloneServer
import CloneProtocol

/// Converts SwiftUI FlatRenderCommand to UniFFI RenderCommand.
public enum Bridge {
    public static func toEngineCommands(_ flatCommands: [FlatRenderCommand]) -> [RenderCommand] {
        flatCommands.map { cmd in
            let cx = Float(cmd.x), cy = Float(cmd.y), cw = Float(cmd.width), ch = Float(cmd.height)
            switch cmd.kind {
            case .rect(let color):
                return .rect(
                    x: cx, y: cy, w: cw, h: ch,
                    color: color.toEngine()
                )
            case .roundedRect(let radius, let color):
                return .roundedRect(
                    x: cx, y: cy, w: cw, h: ch,
                    radius: Float(radius), color: color.toEngine()
                )
            case .text(let content, let fontSize, let color, let weight, let isIcon):
                return .text(
                    x: cx, y: cy,
                    content: content, fontSize: Float(fontSize),
                    color: color.toEngine(),
                    weight: weight.toEngine(),
                    isIcon: isIcon
                )
            case .shadow(let radius, let blur, let color, let offsetX, let offsetY):
                return .shadow(
                    x: cx, y: cy, w: cw, h: ch,
                    radius: Float(radius), blur: Float(blur), color: color.toEngine(),
                    ox: Float(offsetX), oy: Float(offsetY)
                )
            case .pushClip(let radius):
                return .pushClip(
                    x: cx, y: cy, w: cw, h: ch,
                    radius: Float(radius)
                )
            case .popClip:
                return .popClip
            }
        }
    }

    /// Convert IPC render commands to UniFFI commands, offset by window position.
    public static func ipcToEngine(_ ipcCommands: [IPCRenderCommand], offsetX: Float, offsetY: Float) -> [RenderCommand] {
        ipcCommands.map { cmd in
            switch cmd {
            case .rect(let x, let y, let w, let h, let color):
                return .rect(x: x + offsetX, y: y + offsetY, w: w, h: h, color: color.toEngine())
            case .roundedRect(let x, let y, let w, let h, let radius, let color):
                return .roundedRect(x: x + offsetX, y: y + offsetY, w: w, h: h, radius: radius, color: color.toEngine())
            case .text(let x, let y, let content, let fontSize, let color, let weight, let isIcon):
                return .text(x: x + offsetX, y: y + offsetY, content: content, fontSize: fontSize,
                            color: color.toEngine(), weight: weight.toEngine(), isIcon: isIcon)
            case .shadow(let x, let y, let w, let h, let radius, let blur, let color, let ox, let oy):
                return .shadow(x: x + offsetX, y: y + offsetY, w: w, h: h,
                              radius: radius, blur: blur, color: color.toEngine(),
                              ox: ox, oy: oy)
            case .pushClip(let x, let y, let w, let h, let radius):
                return .pushClip(x: x + offsetX, y: y + offsetY, w: w, h: h, radius: radius)
            case .popClip:
                return .popClip
            }
        }
    }

    /// Offset a single IPC command by dy (for title bar offset in local coords).
    public static func offsetIpcCommand(_ cmd: IPCRenderCommand, dy: Float) -> RenderCommand {
        switch cmd {
        case .rect(let x, let y, let w, let h, let color):
            return .rect(x: x, y: y + dy, w: w, h: h, color: color.toEngine())
        case .roundedRect(let x, let y, let w, let h, let radius, let color):
            return .roundedRect(x: x, y: y + dy, w: w, h: h, radius: radius, color: color.toEngine())
        case .text(let x, let y, let content, let fontSize, let color, let weight, let isIcon):
            return .text(x: x, y: y + dy, content: content, fontSize: fontSize,
                        color: color.toEngine(), weight: weight.toEngine(), isIcon: isIcon)
        case .shadow(let x, let y, let w, let h, let radius, let blur, let color, let ox, let oy):
            return .shadow(x: x, y: y + dy, w: w, h: h,
                          radius: radius, blur: blur, color: color.toEngine(),
                          ox: ox, oy: oy)
        case .pushClip(let x, let y, let w, let h, let radius):
            return .pushClip(x: x, y: y + dy, w: w, h: h, radius: radius)
        case .popClip:
            return .popClip
        }
    }
}

extension Color {
    func toEngine() -> RgbaColor {
        RgbaColor(r: Float(r), g: Float(g), b: Float(b), a: Float(a))
    }
}

extension IPCColor {
    func toEngine() -> RgbaColor {
        RgbaColor(r: r, g: g, b: b, a: a)
    }
}

extension SwiftUI.FontWeight {
    func toEngine() -> FontWeight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}

extension IPCFontWeight {
    func toEngine() -> FontWeight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}

/// Swift-side delegate — compositor with window manager, app server, animations, and built-in apps.
@MainActor
public final class SwiftDesktopDelegate: @preconcurrency DesktopDelegate {
    private let animationManager = AnimationManager()
    private var mouseX: Double = 0
    private var mouseY: Double = 0
    private var mouseDown: Bool = false

    private let windowManager = WindowManager()
    private let server = CompositorServer()
    private var focusedAppName: String = "Finder"
    private var childProcesses: [Process] = []
    private var externalWindows: [UInt64: UInt64] = [:] // server windowId → wm windowId
    private var lastLayoutResults: [LayoutNode] = []
    private var pendingLaunches: [String] = []
    private var pendingRestores: [String] = []

    /// Map appId to binary name for launching.
    private let appBinaries: [String: String] = [
        "com.clone.finder": "Finder",
        "com.clone.dock": "Dock",
        "com.clone.menubar": "MenuBar",
        "com.clone.settings": "Settings",
    ]

    public init() {
        // Start IPC server
        do {
            try server.start()
            fputs("Compositor server listening on \(compositorSocketPath)\n", stderr)
        } catch {
            fputs("Failed to start compositor server: \(error)\n", stderr)
        }

        // Wire dock→compositor commands (queued, processed in onCompositeFrame)
        server.onLaunchApp = { [weak self] appId in
            self?.pendingLaunches.append(appId)
        }
        server.onRestoreApp = { [weak self] appId in
            self?.pendingRestores.append(appId)
        }

        // Auto-launch system services and apps
        launchApp("cloned")
        launchApp("Dock")
        launchApp("MenuBar")
        launchApp("Finder")
    }

    /// Launch an app binary as a child process.
    private func launchApp(_ name: String) {
        // Find the binary next to our own executable, or in .build/debug
        let fm = FileManager.default
        let candidates = [
            // Same directory as CloneDesktop
            URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().appendingPathComponent(name).path,
            // SPM build directory
            ".build/debug/\(name)",
            // Relative
            "target/debug/\(name)",
        ]

        guard let path = candidates.first(where: { fm.isExecutableFile(atPath: $0) }) else {
            fputs("Could not find \(name) binary\n", stderr)
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.standardError = FileHandle.standardError
        do {
            try process.run()
            childProcesses.append(process)
            fputs("Launched \(name) (pid \(process.processIdentifier))\n", stderr)
        } catch {
            fputs("Failed to launch \(name): \(error)\n", stderr)
        }
    }

    public func onFrame(surfaceId: UInt64, width: UInt32, height: UInt32) -> [RenderCommand] {
        GeometryReaderRegistry.shared.clear()
        TapRegistry.shared.clear()

        let w = CGFloat(width)
        let h = CGFloat(height)

        // Update screen dimensions for window manager (zoom needs this)
        windowManager.screenWidth = w
        windowManager.screenHeight = h

        // Sync external app windows (server I/O is async via GCD)
        syncExternalApps()
        server.requestFrames()

        let screenFrame = LayoutFrame(x: 0, y: 0, width: w, height: h)

        // 1. Desktop background only
        let desktop = Desktop(
            screenWidth: w,
            screenHeight: h,
            mouseX: CGFloat(mouseX),
            mouseY: CGFloat(mouseY)
        )
        let bgLayout = Layout.layout(desktop.body(), in: screenFrame)
        var engineCommands = Bridge.toEngineCommands(CommandFlattener.flatten(bgLayout))

        // Render each window as a complete unit in z-order.
        // PushClip/PopClip around each window creates a render group boundary,
        // so the Rust renderer flushes all draw calls (rects + text) per window.
        let visibleWindows = windowManager.windows.filter { $0.isVisible && !$0.isMinimized }
        for window in visibleWindows {
            // Window chrome (shadow, background, title bar) — no clipping, shadow extends beyond
            let isFocused = window.id == windowManager.focusedWindowId
            let showSymbols = windowManager.hoveredWindowId == window.id && windowManager.hoveringTrafficLights
            let chromeNodes = windowManager.renderSingle(
                window: window, isFocused: isFocused,
                showTrafficLightSymbols: showSymbols
            )
            let chromeLayout = Layout.layout(chromeNodes, in: screenFrame)
            engineCommands.append(contentsOf: Bridge.toEngineCommands(CommandFlattener.flatten(chromeLayout)))

            // Window content — clipped to window bounds so text doesn't leak
            engineCommands.append(.pushClip(
                x: Float(window.x), y: Float(window.y),
                w: Float(window.width), h: Float(window.height), radius: 0
            ))
            if let serverWid = externalWindowId(for: window.id) {
                let ipcCommands = server.commands(for: serverWid)
                if !ipcCommands.isEmpty {
                    let contentY = Float(window.y + WindowChrome.titleBarHeight)
                    let translated = Bridge.ipcToEngine(ipcCommands, offsetX: Float(window.x), offsetY: contentY)
                    engineCommands.append(contentsOf: translated)
                }
            }
            engineCommands.append(.popClip)
        }

        // Dock — always on top of windows
        let dockTree = VStack(spacing: 0) {
            Spacer()
            Dock(mouseX: CGFloat(mouseX), mouseY: CGFloat(mouseY),
                 screenWidth: w, screenHeight: h).body()
        }.body
        let dockLayout = Layout.layout(dockTree, in: screenFrame)
        engineCommands.append(contentsOf: Bridge.toEngineCommands(CommandFlattener.flatten(dockLayout)))

        // Menu bar — always topmost
        let menuBar = MenuBar(screenWidth: w, appName: focusedAppName, clock: currentTime())
        let menuLayout = Layout.layout(menuBar.body(), in: screenFrame)
        lastLayoutResults = [menuLayout]
        engineCommands.append(contentsOf: Bridge.toEngineCommands(CommandFlattener.flatten(menuLayout)))

        return engineCommands
    }

    // MARK: - Compositor API (per-surface rendering)

    /// Surface IDs: 0 = desktop, 1 = dock, 2 = menubar, 100+ = windows
    private let desktopSurfaceId: UInt64 = 0
    private let dockSurfaceId: UInt64 = 1
    private let menubarSurfaceId: UInt64 = 2
    private let windowSurfaceBase: UInt64 = 100

    public func onCompositeFrame(width: UInt32, height: UInt32) -> [SurfaceFrame] {
        GeometryReaderRegistry.shared.clear()
        TapRegistry.shared.clear()

        let w = CGFloat(width)
        let h = CGFloat(height)

        windowManager.screenWidth = w
        windowManager.screenHeight = h
        syncExternalApps()
        syncResizingAppDimensions()
        server.requestFrames()
        lastLayoutResults = []

        // Process queued dock commands
        for appId in pendingLaunches {
            // Focus existing window if one exists
            if let window = windowManager.windows.first(where: { $0.appId == appId && $0.isVisible && !$0.isMinimized }) {
                windowManager.focus(id: window.id)
                updateFocusedAppName()
            } else if let window = windowManager.minimizedWindows.first(where: { $0.appId == appId }) {
                // Restore minimized window
                animateRestore(windowId: window.id)
            } else if let name = appBinaries[appId] {
                launchApp(name)
            }
        }
        pendingLaunches.removeAll()

        for appId in pendingRestores {
            if let window = windowManager.minimizedWindows.first(where: { $0.appId == appId }) {
                animateRestore(windowId: window.id)
            }
        }
        pendingRestores.removeAll()

        // Tick animations — complete minimize by actually hiding the window
        for (windowId, wasMinimizing) in animationManager.tick() {
            if wasMinimizing {
                windowManager.minimize(id: windowId)
            }
        }

        var frames: [SurfaceFrame] = []

        // 1. Desktop background (wallpaper rendered by engine via Wallpaper command)
        frames.append(SurfaceFrame(
            desc: SurfaceDesc(surfaceId: desktopSurfaceId, x: 0, y: 0, width: Float(w), height: Float(h), cornerRadius: 0, opacity: 1),
            commands: [.wallpaper(x: 0, y: 0, w: Float(w), h: Float(h))]
        ))

        // 2. Windows — visible + currently animating
        let visibleWindows = windowManager.windows.filter {
            ($0.isVisible && !$0.isMinimized) || animationManager.isAnimating($0.id)
        }
        for window in visibleWindows {
            let surfaceId = windowSurfaceBase + window.id
            let isFocused = window.id == windowManager.focusedWindowId
            let showSymbols = windowManager.hoveredWindowId == window.id && windowManager.hoveringTrafficLights
            let radius: CGFloat = window.isMaximized ? 0 : WindowChrome.cornerRadius

            // Build window chrome + content in LOCAL coordinates (0,0 = window top-left)
            var windowCommands: [RenderCommand] = []

            let tbColor: Color = isFocused ? WindowChrome.titleBar : WindowChrome.titleBarUnfocused
            let bgColor: Color = isFocused ? WindowChrome.surface : WindowChrome.background

            let fW = Float(window.width)
            let fH = Float(window.height)
            let fRadius = Float(radius)

            // 1. Window background
            windowCommands.append(.roundedRect(
                x: 0, y: 0, w: fW, h: fH,
                radius: fRadius, color: bgColor.toEngine()
            ))

            // 2. App content (IPC commands — offset by title bar height)
            if let serverWid = externalWindowId(for: window.id) {
                let ipcCommands = server.commands(for: serverWid)
                for cmd in ipcCommands {
                    windowCommands.append(Bridge.offsetIpcCommand(cmd, dy: Float(WindowChrome.titleBarHeight)))
                }
            }

            // 3. Title bar + chrome drawn LAST so they're always on top
            windowCommands.append(.pushClip(x: 0, y: 0, w: fW, h: fH, radius: 0))
            windowCommands.append(.rect(
                x: 0, y: 0, w: fW, h: Float(WindowChrome.titleBarHeight),
                color: tbColor.toEngine()
            ))

            // Traffic lights
            let btnY = Float(WindowChrome.buttonInsetY)
            let btnX = Float(WindowChrome.buttonInsetX)
            let btnSize = Float(WindowChrome.buttonSize)
            let btnStep = btnSize + Float(WindowChrome.buttonSpacing)

            let closeColor: Color = isFocused ? .red : .gray
            let minColor: Color = isFocused ? .yellow : .gray
            let zoomColor: Color = isFocused ? .green : .gray

            windowCommands.append(.roundedRect(x: btnX, y: btnY, w: btnSize, h: btnSize, radius: btnSize / 2, color: closeColor.toEngine()))
            windowCommands.append(.roundedRect(x: btnX + btnStep, y: btnY, w: btnSize, h: btnSize, radius: btnSize / 2, color: minColor.toEngine()))
            windowCommands.append(.roundedRect(x: btnX + btnStep * 2, y: btnY, w: btnSize, h: btnSize, radius: btnSize / 2, color: zoomColor.toEngine()))

            // Traffic light symbols on hover (Phosphor icons)
            if showSymbols {
                let iconSize = btnSize * 0.6
                let symX = { (base: Float) in base + (btnSize - iconSize) / 2 }
                let symY = btnY + (btnSize - iconSize) / 2
                let symColor = RgbaColor(r: 0, g: 0, b: 0, a: 0.5)
                let closeSym = String(PhosphorIcons.character(forName: "xmark")!)
                let minSym = String(PhosphorIcons.character(forName: "minus")!)
                let zoomName = window.isMaximized ? "arrows.in" : "arrows.out"
                let zoomSym = String(PhosphorIcons.character(forName: zoomName)!)
                windowCommands.append(.text(x: symX(btnX), y: symY, content: closeSym, fontSize: iconSize, color: symColor, weight: .regular, isIcon: true))
                windowCommands.append(.text(x: symX(btnX + btnStep), y: symY, content: minSym, fontSize: iconSize, color: symColor, weight: .regular, isIcon: true))
                windowCommands.append(.text(x: symX(btnX + btnStep * 2), y: symY, content: zoomSym, fontSize: iconSize, color: symColor, weight: .regular, isIcon: true))
            }

            // Title text
            let titleColor: Color = isFocused ? .primary : .secondary
            let titleX = fW / 2 - Float(window.title.count) * 4
            let titleY = (Float(WindowChrome.titleBarHeight) - 13) / 2
            windowCommands.append(.text(
                x: titleX, y: titleY, content: window.title, fontSize: 13,
                color: titleColor.toEngine(), weight: .regular, isIcon: false
            ))
            windowCommands.append(.popClip)

            // Apply animation override if this window is animating
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
                    cornerRadius: fRadius,
                    opacity: Float(frameOpacity)
                ),
                commands: windowCommands
            ))
        }

        // 3. Dock and MenuBar — external app surfaces at fixed z-order
        for app in server.connectedApps {
            guard app.role == .dock || app.role == .menubar else { continue }
            let surfaceId = windowSurfaceBase + app.windowId + 10000 // avoid collision with window IDs
            let ipcCommands = app.getCommands()
            if !ipcCommands.isEmpty {
                let engineCommands = ipcCommands.map { Bridge.offsetIpcCommand($0, dy: 0) }
                frames.append(SurfaceFrame(
                    desc: SurfaceDesc(
                        surfaceId: surfaceId,
                        x: 0, y: 0,
                        width: Float(w), height: Float(h),
                        cornerRadius: 0, opacity: 1
                    ),
                    commands: engineCommands
                ))
            }
        }

        // Send state updates to dock and menubar
        notifyDockAndMenuBar()

        return frames
    }

    public func onPointerMove(surfaceId: UInt64, x: Double, y: Double) {
        mouseX = x
        mouseY = y
        let mx = CGFloat(x)
        let my = CGFloat(y)

        if windowManager.isResizing {
            windowManager.updateResize(mouseX: mx, mouseY: my)
            return
        }

        if windowManager.isDragging {
            windowManager.updateDrag(mouseX: mx, mouseY: my)
            return
        }

        // Update traffic light hover state
        if let window = windowManager.windowAt(x: mx, y: my) {
            windowManager.hoveredWindowId = window.id
            windowManager.hoveringTrafficLights = windowManager.isOverTrafficLights(
                windowId: window.id, x: mx, y: my
            )
        } else {
            windowManager.hoveredWindowId = nil
            windowManager.hoveringTrafficLights = false
        }

        // Forward to focused external app
        if let focusedId = windowManager.focusedWindowId,
           let serverWid = externalWindowId(for: focusedId),
           let window = windowManager.windows.first(where: { $0.id == focusedId }) {
            let localX = mx - window.x
            let localY = my - window.y - WindowChrome.titleBarHeight
            server.sendPointerMove(windowId: serverWid, x: Float(localX), y: Float(localY))
        }
    }

    public func onPointerButton(surfaceId: UInt64, button: UInt32, pressed: Bool) {
        let mx = CGFloat(mouseX)
        let my = CGFloat(mouseY)

        if button == 0 {
            if pressed {
                mouseDown = true

                // Check resize edges first (works even outside the window rect)
                for window in windowManager.windows.reversed() where window.isVisible && !window.isMinimized {
                    if let edge = windowManager.hitTestResizeEdge(windowId: window.id, x: mx, y: my) {
                        windowManager.beginResize(windowId: window.id, edge: edge, mouseX: mx, mouseY: my)
                        return
                    }
                }

                if let window = windowManager.windowAt(x: mx, y: my) {
                    // Traffic light buttons
                    if let trafficLight = windowManager.hitTestTrafficLight(windowId: window.id, x: mx, y: my) {
                        switch trafficLight {
                        case .close:
                            if let serverWid = externalWindowId(for: window.id) {
                                externalWindows.removeValue(forKey: serverWid)
                            }
                            windowManager.close(id: window.id)
                        case .minimize:
                            animateMinimize(windowId: window.id)
                        case .zoom:
                            windowManager.zoom(id: window.id)
                            notifyExternalAppResize(wmWindowId: window.id)
                        }
                        updateFocusedAppName()
                        return
                    }

                    // Title bar drag (but not on traffic lights)
                    if window.titleBarContains(px: mx, py: my) {
                        let wasMaximized = windowManager.windows.first(where: { $0.id == window.id })?.isMaximized ?? false
                        windowManager.beginDrag(windowId: window.id, mouseX: mx, mouseY: my)
                        if wasMaximized {
                            notifyExternalAppResize(wmWindowId: window.id)
                        }
                    } else if let serverWid = externalWindowId(for: window.id) {
                        let localX = mx - window.x
                        let localY = my - window.y - WindowChrome.titleBarHeight
                        server.sendPointerButton(windowId: serverWid, button: button, pressed: true, x: Float(localX), y: Float(localY))
                    }

                    windowManager.focus(id: window.id)
                    updateFocusedAppName()
                } else {
                    // No window hit — forward click to dock/menubar overlays
                    for app in server.connectedApps where app.role == .dock || app.role == .menubar {
                        server.sendPointerButton(windowId: app.windowId, button: button, pressed: true, x: Float(mx), y: Float(my))
                    }
                }
            } else {
                mouseDown = false

                if windowManager.isResizing {
                    if let wid = windowManager.resizingWindowId {
                        notifyExternalAppResize(wmWindowId: wid)
                    }
                    windowManager.endResize()
                }
                windowManager.endDrag()

                if let focusedId = windowManager.focusedWindowId,
                   let serverWid = externalWindowId(for: focusedId) {
                    server.sendPointerButton(windowId: serverWid, button: button, pressed: false, x: 0, y: 0)
                }
            }
        } else {
            // Non-left buttons (right-click = button 1, etc.)
            // Forward to app without drag/resize/traffic-light logic
            if pressed {
                if let window = windowManager.windowAt(x: mx, y: my) {
                    windowManager.focus(id: window.id)
                    updateFocusedAppName()
                    if let serverWid = externalWindowId(for: window.id) {
                        let localX = mx - window.x
                        let localY = my - window.y - WindowChrome.titleBarHeight
                        server.sendPointerButton(windowId: serverWid, button: button, pressed: true, x: Float(localX), y: Float(localY))
                    }
                }
            } else {
                if let focusedId = windowManager.focusedWindowId,
                   let serverWid = externalWindowId(for: focusedId) {
                    server.sendPointerButton(windowId: serverWid, button: button, pressed: false, x: 0, y: 0)
                }
            }
        }
    }

    public func wallpaperPath() -> String {
        let fm = FileManager.default
        // Resolve the executable's real location to find the project root
        let execURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let projectRoot = execURL
            .deletingLastPathComponent()  // .build/debug/
            .deletingLastPathComponent()  // .build/
            .deletingLastPathComponent()  // project root
        let candidates = [
            projectRoot.appendingPathComponent("engine/assets/wallpaper.jpg").path,
            // CWD-relative fallback
            fm.currentDirectoryPath + "/engine/assets/wallpaper.jpg",
        ]
        let result = candidates.first(where: { fm.fileExists(atPath: $0) }) ?? ""
        fputs("Wallpaper path: \(result.isEmpty ? "(none)" : result)\n", stderr)
        return result
    }

    public func onKey(surfaceId: UInt64, keycode: UInt32, pressed: Bool) {
        guard pressed else { return }

        // Forward to focused external app
        if let focusedId = windowManager.focusedWindowId,
           let serverWid = externalWindowId(for: focusedId) {
            server.sendKey(windowId: serverWid, keycode: keycode, pressed: pressed)
            return
        }

        // Compositor key bindings (only when no external app focused)
        switch keycode {
        case 53: // 'w' — close focused window
            if let id = windowManager.focusedWindowId {
                windowManager.close(id: id)
                updateFocusedAppName()
            }
        default:
            break
        }
    }

    // MARK: - External app sync

    /// Create WindowManager windows for newly connected window-role apps.
    private func syncExternalApps() {
        for app in server.connectedApps {
            if app.appId == "pending" { continue }
            if app.role != .window { continue } // dock/menubar don't get managed windows
            if externalWindows[app.windowId] != nil { continue }

            let wmId = windowManager.open(
                appId: app.appId,
                title: app.title,
                x: 150 + CGFloat.random(in: 0...200),
                y: 50 + CGFloat.random(in: 0...150),
                width: CGFloat(app.width),
                height: CGFloat(app.height) + WindowChrome.titleBarHeight
            )
            externalWindows[app.windowId] = wmId
            updateFocusedAppName()
        }

        // Sync titles from window-role apps
        for app in server.connectedApps where app.role == .window {
            if let wmId = externalWindows[app.windowId],
               let idx = windowManager.windows.firstIndex(where: { $0.id == wmId }) {
                windowManager.windows[idx].title = app.title
            }
        }
    }

    private func externalWindowId(for wmWindowId: UInt64) -> UInt64? {
        externalWindows.first(where: { $0.value == wmWindowId })?.key
    }

    /// Walk all layout trees for onTap nodes at the given point and fire them.
    private func fireTapAt(x: CGFloat, y: CGFloat) {
        for layout in lastLayoutResults {
            fireTapInNode(layout, x: x, y: y)
        }
    }

    private func fireTapInNode(_ node: LayoutNode, x: CGFloat, y: CGFloat) {
        guard node.frame.contains(x: x, y: y) else { return }
        if case .onTap(let id, _) = node.node {
            TapRegistry.shared.fire(id: id)
        }
        for child in node.children.reversed() {
            fireTapInNode(child, x: x, y: y)
        }
    }

    /// Check if a dock icon was tapped — restore minimized window or launch new.
    private func handleDockAction() {
        guard let appId = DockActionRegistry.shared.consume() else { return }

        // Check if there's a minimized window for this app to restore
        if let window = windowManager.minimizedWindows.first(where: { $0.appId == appId }) {
            animateRestore(windowId: window.id)
            return
        }

        // Otherwise launch a new instance
        if let binaryName = appBinaries[appId] {
            launchApp(binaryName)
        } else {
            fputs("No binary registered for \(appId)\n", stderr)
        }
    }

    // MARK: - Genie animations

    private func animateMinimize(windowId: UInt64) {
        guard let window = windowManager.windows.first(where: { $0.id == windowId }) else { return }
        let from = AnimRect(x: window.x, y: window.y, w: window.width, h: window.height)

        // Target: the dock icon for this app
        let iconIndex = Dock.iconIndex(for: window.appId) ?? 0
        let to = Dock.iconRect(index: iconIndex, screenWidth: windowManager.screenWidth, screenHeight: windowManager.screenHeight)

        animationManager.startMinimize(windowId: windowId, from: from, to: to)
        // Don't hide yet — the animation will show the window shrinking.
        // We hide it when the animation completes in onCompositeFrame.
    }

    private func animateRestore(windowId: UInt64) {
        guard let window = windowManager.windows.first(where: { $0.id == windowId }) else { return }

        // Source: the dock icon
        let iconIndex = Dock.iconIndex(for: window.appId) ?? 0
        let from = Dock.iconRect(index: iconIndex, screenWidth: windowManager.screenWidth, screenHeight: windowManager.screenHeight)
        let to = AnimRect(x: window.x, y: window.y, w: window.width, h: window.height)

        // Unminimize first so the surface exists for compositing
        windowManager.unminimize(id: windowId)
        animationManager.startRestore(windowId: windowId, from: from, to: to)
    }

    /// Sync external app dimensions with the WindowManager during resize so
    /// apps receive the live size in requestFrames() and redraw continuously.
    private func syncResizingAppDimensions() {
        guard let wmId = windowManager.resizingWindowId,
              let serverWid = externalWindowId(for: wmId),
              let window = windowManager.windows.first(where: { $0.id == wmId }) else { return }
        let contentWidth = window.width
        let contentHeight = window.height - WindowChrome.titleBarHeight
        server.updateAppDimensions(windowId: serverWid, width: Float(contentWidth), height: Float(contentHeight))
    }

    /// Notify an external app that its window was resized (zoom/unmaximize).
    private func notifyExternalAppResize(wmWindowId: UInt64) {
        guard let serverWid = externalWindowId(for: wmWindowId),
              let window = windowManager.windows.first(where: { $0.id == wmWindowId }) else { return }
        let contentWidth = window.width
        let contentHeight = window.height - WindowChrome.titleBarHeight
        server.sendResize(windowId: serverWid, width: Float(contentWidth), height: Float(contentHeight))
    }

    private func updateFocusedAppName() {
        if let id = windowManager.focusedWindowId,
           let window = windowManager.windows.first(where: { $0.id == id }) {
            // Check if external
            if let serverWid = externalWindowId(for: id),
               let app = server.app(for: serverWid) {
                focusedAppName = app.title
            } else {
                focusedAppName = window.title
            }
        } else {
            focusedAppName = "Finder"
        }
    }

    /// Send state updates to dock and menubar apps.
    private func notifyDockAndMenuBar() {
        let minimizedIds = windowManager.minimizedWindows.map(\.appId)
        for app in server.connectedApps {
            switch app.role {
            case .dock:
                app.send(.minimizedApps(appIds: minimizedIds))
                // Forward mouse position (screen coords) so dock can do hover
                app.send(.pointerMove(x: Float(mouseX), y: Float(mouseY)))
            case .menubar:
                app.send(.focusedApp(name: focusedAppName))
            case .window:
                break
            }
        }
    }

    private func currentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}

/// Launch the desktop. Call from main.swift.
@MainActor public func launchDesktop() throws {
    let delegate = SwiftDesktopDelegate()
    try runDesktop(delegate: delegate)
}
