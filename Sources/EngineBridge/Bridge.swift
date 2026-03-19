import Foundation
import DesktopKit
import CloneServer
import CloneProtocol

/// Converts DesktopKit FlatRenderCommand to UniFFI RenderCommand.
public enum Bridge {
    public static func toEngineCommands(_ flatCommands: [FlatRenderCommand]) -> [RenderCommand] {
        flatCommands.map { cmd in
            switch cmd.kind {
            case .rect(let color):
                return .rect(
                    x: cmd.x, y: cmd.y, w: cmd.width, h: cmd.height,
                    color: color.toEngine()
                )
            case .roundedRect(let radius, let color):
                return .roundedRect(
                    x: cmd.x, y: cmd.y, w: cmd.width, h: cmd.height,
                    radius: radius, color: color.toEngine()
                )
            case .text(let content, let fontSize, let color, let weight):
                return .text(
                    x: cmd.x, y: cmd.y,
                    content: content, fontSize: fontSize,
                    color: color.toEngine(),
                    weight: weight.toEngine()
                )
            case .shadow(let radius, let blur, let color, let offsetX, let offsetY):
                return .shadow(
                    x: cmd.x, y: cmd.y, w: cmd.width, h: cmd.height,
                    radius: radius, blur: blur, color: color.toEngine(),
                    ox: offsetX, oy: offsetY
                )
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
            case .text(let x, let y, let content, let fontSize, let color, let weight):
                return .text(x: x + offsetX, y: y + offsetY, content: content, fontSize: fontSize,
                            color: color.toEngine(), weight: weight.toEngine())
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
        case .text(let x, let y, let content, let fontSize, let color, let weight):
            return .text(x: x, y: y + dy, content: content, fontSize: fontSize,
                        color: color.toEngine(), weight: weight.toEngine())
        }
    }
}

extension DesktopColor {
    func toEngine() -> RgbaColor {
        RgbaColor(r: r, g: g, b: b, a: a)
    }
}

extension IPCColor {
    func toEngine() -> RgbaColor {
        RgbaColor(r: r, g: g, b: b, a: a)
    }
}

extension DesktopKit.FontWeight {
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
public final class SwiftDesktopDelegate: DesktopDelegate {
    private let animationManager = AnimationManager()
    private var mouseX: Double = 0
    private var mouseY: Double = 0
    private var mouseDown: Bool = false

    private let windowManager = WindowManager()
    private let server = CompositorServer()
    private var focusedAppName: String = "Finder"
    private var childProcesses: [Process] = []
    private var externalWindows: [UInt64: UInt64] = [:] // server windowId → wm windowId
    private var lastLayoutResult: LayoutNode? = nil

    /// Map appId to binary name for launching.
    private let appBinaries: [String: String] = [
        "com.clone.finder": "Finder",
        // Add more as they become real binaries:
        // "com.clone.terminal": "Terminal",
        // "com.clone.settings": "Settings",
    ]

    public init() {
        // Start IPC server
        do {
            try server.start()
            fputs("Compositor server listening on \(compositorSocketPath)\n", stderr)
        } catch {
            fputs("Failed to start compositor server: \(error)\n", stderr)
        }

        // Auto-launch Finder
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

        let w = Float(width)
        let h = Float(height)

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
            mouseX: Float(mouseX),
            mouseY: Float(mouseY)
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
                x: window.x, y: window.y,
                w: window.width, h: window.height, radius: 0
            ))
            if let serverWid = externalWindowId(for: window.id) {
                let ipcCommands = server.commands(for: serverWid)
                if !ipcCommands.isEmpty {
                    let contentY = window.y + WindowChrome.titleBarHeight
                    let translated = Bridge.ipcToEngine(ipcCommands, offsetX: window.x, offsetY: contentY)
                    engineCommands.append(contentsOf: translated)
                }
            }
            engineCommands.append(.popClip)
        }

        // Dock — always on top of windows
        let dockTree = VStack(spacing: 0) {
            Spacer()
            Dock(mouseX: Float(mouseX), mouseY: Float(mouseY),
                 screenWidth: w, screenHeight: h).body()
        }
        let dockLayout = Layout.layout(dockTree, in: screenFrame)
        engineCommands.append(contentsOf: Bridge.toEngineCommands(CommandFlattener.flatten(dockLayout)))

        // Menu bar — always topmost
        let menuBar = MenuBar(screenWidth: w, appName: focusedAppName, clock: currentTime())
        let menuLayout = Layout.layout(menuBar.body(), in: screenFrame)
        lastLayoutResult = menuLayout
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

        let w = Float(width)
        let h = Float(height)

        windowManager.screenWidth = w
        windowManager.screenHeight = h
        syncExternalApps()
        server.requestFrames()

        // Tick animations — complete minimize by actually hiding the window
        for (windowId, wasMinimizing) in animationManager.tick() {
            if wasMinimizing {
                windowManager.minimize(id: windowId)
            }
        }

        var frames: [SurfaceFrame] = []

        // 1. Desktop background
        let desktop = Desktop(screenWidth: w, screenHeight: h, mouseX: Float(mouseX), mouseY: Float(mouseY))
        let desktopLayout = Layout.layout(desktop.body(), in: LayoutFrame(x: 0, y: 0, width: w, height: h))
        frames.append(SurfaceFrame(
            desc: SurfaceDesc(surfaceId: desktopSurfaceId, x: 0, y: 0, width: w, height: h, cornerRadius: 0, opacity: 1),
            commands: Bridge.toEngineCommands(CommandFlattener.flatten(desktopLayout))
        ))

        // 2. Windows — visible + currently animating
        let visibleWindows = windowManager.windows.filter {
            ($0.isVisible && !$0.isMinimized) || animationManager.isAnimating($0.id)
        }
        for window in visibleWindows {
            let surfaceId = windowSurfaceBase + window.id
            let isFocused = window.id == windowManager.focusedWindowId
            let showSymbols = windowManager.hoveredWindowId == window.id && windowManager.hoveringTrafficLights
            let radius = window.isMaximized ? Float(0) : WindowChrome.cornerRadius

            // Build window chrome + content in LOCAL coordinates (0,0 = window top-left)
            var windowCommands: [RenderCommand] = []

            // Title bar background
            let tbColor: DesktopColor = isFocused
                ? DesktopColor(r: 0.24, g: 0.22, b: 0.30)
                : DesktopColor(r: 0.19, g: 0.17, b: 0.24)
            let bgColor: DesktopColor = isFocused
                ? .surface
                : DesktopColor(r: 0.16, g: 0.15, b: 0.21)

            // Window background (local coords)
            windowCommands.append(.roundedRect(
                x: 0, y: 0, w: window.width, h: window.height,
                radius: radius, color: bgColor.toEngine()
            ))
            // Title bar
            windowCommands.append(.rect(
                x: 0, y: 0, w: window.width, h: WindowChrome.titleBarHeight,
                color: tbColor.toEngine()
            ))

            // Traffic lights
            let btnY = WindowChrome.buttonInsetY
            let btnX = WindowChrome.buttonInsetX
            let btnSize = WindowChrome.buttonSize
            let btnStep = btnSize + WindowChrome.buttonSpacing

            let closeColor: DesktopColor = isFocused ? .systemRed : .muted
            let minColor: DesktopColor = isFocused ? .systemYellow : .muted
            let zoomColor: DesktopColor = isFocused ? .systemGreen : .muted

            windowCommands.append(.roundedRect(x: btnX, y: btnY, w: btnSize, h: btnSize, radius: btnSize / 2, color: closeColor.toEngine()))
            windowCommands.append(.roundedRect(x: btnX + btnStep, y: btnY, w: btnSize, h: btnSize, radius: btnSize / 2, color: minColor.toEngine()))
            windowCommands.append(.roundedRect(x: btnX + btnStep * 2, y: btnY, w: btnSize, h: btnSize, radius: btnSize / 2, color: zoomColor.toEngine()))

            // Traffic light symbols on hover
            if showSymbols {
                let symY = btnY + (btnSize - 9) / 2
                let symColor = RgbaColor(r: 0, g: 0, b: 0, a: 0.5)
                windowCommands.append(.text(x: btnX + 2, y: symY, content: "×", fontSize: btnSize * 0.7, color: symColor, weight: .bold))
                windowCommands.append(.text(x: btnX + btnStep + 2, y: symY, content: "−", fontSize: btnSize * 0.7, color: symColor, weight: .bold))
                let zoomSym = window.isMaximized ? "↙" : "↗"
                windowCommands.append(.text(x: btnX + btnStep * 2 + 2, y: symY, content: zoomSym, fontSize: btnSize * 0.7, color: symColor, weight: .bold))
            }

            // Title text
            let titleColor: DesktopColor = isFocused ? .text : .subtle
            let titleX = window.width / 2 - Float(window.title.count) * 4
            let titleY = (WindowChrome.titleBarHeight - 13) / 2
            windowCommands.append(.text(
                x: titleX, y: titleY, content: window.title, fontSize: 13,
                color: titleColor.toEngine(), weight: .regular
            ))

            // App content (IPC commands — already in local coords)
            if let serverWid = externalWindowId(for: window.id) {
                let ipcCommands = server.commands(for: serverWid)
                for cmd in ipcCommands {
                    // Offset by title bar height (IPC coords are relative to content area)
                    windowCommands.append(Bridge.offsetIpcCommand(cmd, dy: WindowChrome.titleBarHeight))
                }
            }

            // Apply animation override if this window is animating
            var frameX = window.x
            var frameY = window.y
            var frameW = window.width
            var frameH = window.height
            var frameOpacity: Float = 1.0

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
                    x: frameX, y: frameY,
                    width: frameW, height: frameH,
                    cornerRadius: radius,
                    opacity: frameOpacity
                ),
                commands: windowCommands
            ))
        }

        // 3. Dock
        let dockTree = VStack(spacing: 0) {
            Spacer()
            Dock(mouseX: Float(mouseX), mouseY: Float(mouseY), screenWidth: w, screenHeight: h).body()
        }
        let dockLayout = Layout.layout(dockTree, in: LayoutFrame(x: 0, y: 0, width: w, height: h))
        frames.append(SurfaceFrame(
            desc: SurfaceDesc(surfaceId: dockSurfaceId, x: 0, y: 0, width: w, height: h, cornerRadius: 0, opacity: 1),
            commands: Bridge.toEngineCommands(CommandFlattener.flatten(dockLayout))
        ))

        // 4. Menu bar
        let menuBar = MenuBar(screenWidth: w, appName: focusedAppName, clock: currentTime())
        let menuLayout = Layout.layout(menuBar.body(), in: LayoutFrame(x: 0, y: 0, width: w, height: h))
        frames.append(SurfaceFrame(
            desc: SurfaceDesc(surfaceId: menubarSurfaceId, x: 0, y: 0, width: w, height: h, cornerRadius: 0, opacity: 1),
            commands: Bridge.toEngineCommands(CommandFlattener.flatten(menuLayout))
        ))

        return frames
    }

    public func onPointerMove(surfaceId: UInt64, x: Double, y: Double) {
        mouseX = x
        mouseY = y
        let mx = Float(x)
        let my = Float(y)

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
            server.sendPointerMove(windowId: serverWid, x: localX, y: localY)
        }
    }

    public func onPointerButton(surfaceId: UInt64, button: UInt32, pressed: Bool) {
        let mx = Float(mouseX)
        let my = Float(mouseY)

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
                        server.sendPointerButton(windowId: serverWid, button: button, pressed: true, x: localX, y: localY)
                    }

                    windowManager.focus(id: window.id)
                    updateFocusedAppName()
                } else {
                    // No window hit — check for tap handlers (dock icons, etc.)
                    fireTapAt(x: mx, y: my)
                    handleDockAction()
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
        }
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

    /// Create WindowManager windows for newly connected external apps.
    private func syncExternalApps() {
        for app in server.connectedApps {
            if app.appId == "pending" { continue }
            if externalWindows[app.windowId] != nil { continue }

            // New app connected — create a window for it
            let wmId = windowManager.open(
                appId: app.appId,
                title: app.title,
                x: 150 + Float.random(in: 0...200),
                y: 50 + Float.random(in: 0...150),
                width: app.width,
                height: app.height + WindowChrome.titleBarHeight
            )
            externalWindows[app.windowId] = wmId
            updateFocusedAppName()
        }

        // Sync titles from external apps
        for app in server.connectedApps {
            if let wmId = externalWindows[app.windowId],
               let idx = windowManager.windows.firstIndex(where: { $0.id == wmId }) {
                windowManager.windows[idx].title = app.title
            }
        }
    }

    private func externalWindowId(for wmWindowId: UInt64) -> UInt64? {
        externalWindows.first(where: { $0.value == wmWindowId })?.key
    }

    /// Walk the layout tree for onTap nodes at the given point and fire them.
    private func fireTapAt(x: Float, y: Float) {
        guard let layout = lastLayoutResult else { return }
        fireTapInNode(layout, x: x, y: y)
    }

    private func fireTapInNode(_ node: LayoutNode, x: Float, y: Float) {
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

    /// Notify an external app that its window was resized (zoom/unmaximize).
    private func notifyExternalAppResize(wmWindowId: UInt64) {
        guard let serverWid = externalWindowId(for: wmWindowId),
              let window = windowManager.windows.first(where: { $0.id == wmWindowId }) else { return }
        let contentWidth = window.width
        let contentHeight = window.height - WindowChrome.titleBarHeight
        server.sendResize(windowId: serverWid, width: contentWidth, height: contentHeight)
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

    private func currentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}

/// Launch the desktop. Call from main.swift.
public func launchDesktop() throws {
    let delegate = SwiftDesktopDelegate()
    try runDesktop(delegate: delegate)
}
