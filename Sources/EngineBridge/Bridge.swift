import Foundation
import DesktopKit

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
}

extension DesktopColor {
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

/// Swift-side delegate — compositor with window manager and app registry.
public final class SwiftDesktopDelegate: DesktopDelegate {
    private var mouseX: Double = 0
    private var mouseY: Double = 0
    private var mouseDown: Bool = false

    private let windowManager = WindowManager()
    private let registry = AppRegistry.shared
    private var focusedAppName: String = "Finder"

    public init() {
        // Register built-in apps
        registry.register(FinderApp())
        registry.register(TerminalApp())
        registry.register(SettingsApp())

        // Launch Finder by default
        registry.launch("com.clone.finder", windowManager: windowManager, x: 200, y: 60)
    }

    public func onFrame(surfaceId: UInt64, width: UInt32, height: UInt32) -> [RenderCommand] {
        GeometryReaderRegistry.shared.clear()

        let w = Float(width)
        let h = Float(height)

        // Desktop background + dock
        let desktop = Desktop(
            screenWidth: w,
            screenHeight: h,
            mouseX: Float(mouseX),
            mouseY: Float(mouseY)
        )

        // Menu bar — show focused window's app name
        let menuBar = MenuBar(screenWidth: w, appName: focusedAppName, clock: currentTime())

        // Build scene: desktop + menubar + windows
        let windowNodes = windowManager.render { window in
            guard let app = self.registry.get(window.appId) else {
                return Rectangle().fill(.surface)
            }
            return app.body(
                width: window.width,
                height: window.height - WindowChrome.titleBarHeight
            )
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

        // Layout + flatten
        let layoutResult = Layout.layout(tree, in: LayoutFrame(x: 0, y: 0, width: w, height: h))
        let flatCommands = CommandFlattener.flatten(layoutResult)

        return Bridge.toEngineCommands(flatCommands)
    }

    public func onPointerMove(surfaceId: UInt64, x: Double, y: Double) {
        mouseX = x
        mouseY = y
        if windowManager.isDragging {
            windowManager.updateDrag(mouseX: Float(x), mouseY: Float(y))
        }
    }

    public func onPointerButton(surfaceId: UInt64, button: UInt32, pressed: Bool) {
        let mx = Float(mouseX)
        let my = Float(mouseY)

        if button == 0 { // left click
            if pressed {
                mouseDown = true

                // Check if clicking a window
                if let window = windowManager.windowAt(x: mx, y: my) {
                    // Close button?
                    if windowManager.hitsCloseButton(windowId: window.id, x: mx, y: my) {
                        windowManager.close(id: window.id)
                        updateFocusedAppName()
                        return
                    }

                    // Title bar drag?
                    if window.titleBarContains(px: mx, py: my) {
                        windowManager.beginDrag(windowId: window.id, mouseX: mx, mouseY: my)
                    }

                    // Focus
                    windowManager.focus(id: window.id)
                    updateFocusedAppName()
                }
            } else {
                mouseDown = false
                windowManager.endDrag()
            }
        }
    }

    public func onKey(surfaceId: UInt64, keycode: UInt32, pressed: Bool) {
        guard pressed else { return }

        // Launch apps with number keys
        // Key codes (winit KeyCode enum values):
        // 1=30, 2=31, 3=32 on US layout
        switch keycode {
        case 18: // '1' key
            registry.launch("com.clone.finder", windowManager: windowManager,
                          x: 150 + Float.random(in: 0...100),
                          y: 50 + Float.random(in: 0...100))
        case 19: // '2' key
            registry.launch("com.clone.terminal", windowManager: windowManager,
                          x: 200 + Float.random(in: 0...100),
                          y: 80 + Float.random(in: 0...100))
        case 20: // '3' key
            registry.launch("com.clone.settings", windowManager: windowManager,
                          x: 250 + Float.random(in: 0...100),
                          y: 60 + Float.random(in: 0...100))
        case 53: // 'w' — close focused window (Cmd+W style)
            if let id = windowManager.focusedWindowId {
                windowManager.close(id: id)
                updateFocusedAppName()
            }
        default:
            break
        }
    }

    private func updateFocusedAppName() {
        if let id = windowManager.focusedWindowId,
           let window = windowManager.windows.first(where: { $0.id == id }),
           let app = registry.get(window.appId) {
            focusedAppName = app.defaultTitle
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
