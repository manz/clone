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

/// Swift-side delegate — compositor with window manager, app server, and built-in apps.
public final class SwiftDesktopDelegate: DesktopDelegate {
    private var mouseX: Double = 0
    private var mouseY: Double = 0
    private var mouseDown: Bool = false

    private let windowManager = WindowManager()
    private let server = CompositorServer()
    private var focusedAppName: String = "Finder"

    // Map external app windowIds (from server) to our windowManager windowIds
    private var externalWindows: [UInt64: UInt64] = [:] // server windowId → wm windowId

    public init() {
        // Start IPC server
        do {
            try server.start()
            fputs("Compositor server listening on \(compositorSocketPath)\n", stderr)
        } catch {
            fputs("Failed to start compositor server: \(error)\n", stderr)
        }
    }

    public func onFrame(surfaceId: UInt64, width: UInt32, height: UInt32) -> [RenderCommand] {
        GeometryReaderRegistry.shared.clear()
        TapRegistry.shared.clear()

        // Sync external app windows (server I/O is async via GCD)
        syncExternalApps()
        server.requestFrames()

        let w = Float(width)
        let h = Float(height)

        // Desktop background + dock
        let desktop = Desktop(
            screenWidth: w,
            screenHeight: h,
            mouseX: Float(mouseX),
            mouseY: Float(mouseY)
        )

        let menuBar = MenuBar(screenWidth: w, appName: focusedAppName, clock: currentTime())

        // Built-in window content
        let windowNodes = windowManager.render { window in
            // Check if this is an external app window
            if let serverWid = self.externalWindowId(for: window.id) {
                // External app — we'll overlay its commands separately
                return Rectangle().fill(.clear)
            }
            // Built-in app
            return Rectangle().fill(.surface)
        }

        var layers: [ViewNode] = [
            desktop.body(),
            VStack(alignment: .leading, spacing: 0) {
                menuBar.body()
                Spacer()
            },
        ]
        layers.append(contentsOf: windowNodes)

        let tree = ViewNode.zstack(children: layers)

        // Layout + flatten built-in UI
        let layoutResult = Layout.layout(tree, in: LayoutFrame(x: 0, y: 0, width: w, height: h))
        var engineCommands = Bridge.toEngineCommands(CommandFlattener.flatten(layoutResult))

        // Overlay external app render commands inside their window frames
        for window in windowManager.windows {
            if let serverWid = externalWindowId(for: window.id) {
                let ipcCommands = server.commands(for: serverWid)
                if !ipcCommands.isEmpty {
                    let contentY = window.y + WindowChrome.titleBarHeight
                    let translated = Bridge.ipcToEngine(ipcCommands, offsetX: window.x, offsetY: contentY)
                    engineCommands.append(contentsOf: translated)
                }
            }
        }

        return engineCommands
    }

    public func onPointerMove(surfaceId: UInt64, x: Double, y: Double) {
        mouseX = x
        mouseY = y
        if windowManager.isDragging {
            windowManager.updateDrag(mouseX: Float(x), mouseY: Float(y))
            return
        }

        // Forward to focused external app
        if let focusedId = windowManager.focusedWindowId,
           let serverWid = externalWindowId(for: focusedId),
           let window = windowManager.windows.first(where: { $0.id == focusedId }) {
            let localX = Float(x) - window.x
            let localY = Float(y) - window.y - WindowChrome.titleBarHeight
            server.sendPointerMove(windowId: serverWid, x: localX, y: localY)
        }
    }

    public func onPointerButton(surfaceId: UInt64, button: UInt32, pressed: Bool) {
        let mx = Float(mouseX)
        let my = Float(mouseY)

        if button == 0 {
            if pressed {
                mouseDown = true

                if let window = windowManager.windowAt(x: mx, y: my) {
                    if windowManager.hitsCloseButton(windowId: window.id, x: mx, y: my) {
                        // If external, tell the app
                        if let serverWid = externalWindowId(for: window.id) {
                            externalWindows.removeValue(forKey: serverWid)
                        }
                        windowManager.close(id: window.id)
                        updateFocusedAppName()
                        return
                    }

                    if window.titleBarContains(px: mx, py: my) {
                        windowManager.beginDrag(windowId: window.id, mouseX: mx, mouseY: my)
                    } else if let serverWid = externalWindowId(for: window.id) {
                        // Click inside external app content area
                        let localX = mx - window.x
                        let localY = my - window.y - WindowChrome.titleBarHeight
                        server.sendPointerButton(windowId: serverWid, button: button, pressed: true, x: localX, y: localY)
                    }

                    windowManager.focus(id: window.id)
                    updateFocusedAppName()
                }
            } else {
                mouseDown = false
                windowManager.endDrag()

                // Forward button release to external app
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
