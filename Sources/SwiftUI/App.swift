import Foundation
import CloneClient
import CloneProtocol

// MARK: - Window Configuration

/// Configuration for the app window.
public struct WindowConfiguration {
    public var title: String
    public var width: CGFloat
    public var height: CGFloat
    public var role: SurfaceRole

    public init(title: String, width: CGFloat = 600, height: CGFloat = 400, role: SurfaceRole = .window) {
        self.title = title
        self.width = width
        self.height = height
        self.role = role
    }
}

// MARK: - App Protocol

/// The entry point for a Clone app. Mirrors Apple's SwiftUI App protocol.
///
/// **Declarative rendering** (new apps):
/// ```swift
/// @main
/// struct MyApp: App {
///     var body: some Scene {
///         WindowGroup("My App") { Text("Hello") }
///     }
/// }
/// ```
///
/// **Imperative rendering** (for apps that produce IPCRenderCommand directly):
/// Override `render(width:height:)` and event handlers.
@MainActor
public protocol App {
    associatedtype Body: Scene
    @SceneBuilder var body: Body { get }
    init()

    /// Window configuration. Default uses the WindowGroup title + 600x400 window role.
    var configuration: WindowConfiguration { get }

    /// The AppClient instance. Override only if you need to send custom messages.
    var client: AppClient { get }

    /// Imperative render — return commands directly. Return nil to use the declarative body.
    func render(width: CGFloat, height: CGFloat) -> [IPCRenderCommand]?

    /// Called on pointer movement.
    func onPointerMove(x: CGFloat, y: CGFloat)

    /// Called on pointer button events.
    func onPointerButton(button: UInt32, pressed: Bool, x: CGFloat, y: CGFloat)

    /// Called on key events.
    func onKey(keycode: UInt32, pressed: Bool)

    /// Called when a character is typed (translated from keycode).
    func onKeyChar(character: String)

    /// Called when a menu item is selected from the menu bar.
    func onMenuAction(itemId: String)

    /// Called when an open-file dialog returns a result.
    func onOpenPanelResult(path: String?)

    /// Called when compositor sends the focused app's menus (for menubar).
    func onAppMenus(appName: String, menus: [AppMenu])

    /// Called when compositor reports the focused app name (menubar).
    func onFocusedApp(name: String)

    /// Called when compositor reports minimized app IDs (dock).
    func onMinimizedApps(appIds: [String])
}

// MARK: - Default Implementations

/// Shared AppClient singleton for the running app.
@MainActor private var _sharedClient = AppClient()

extension App {
    public var client: AppClient { _sharedClient }

    public var configuration: WindowConfiguration {
        let scene = body
        if let wg = scene as? (any _WindowGroupProtocol) {
            return WindowConfiguration(title: wg.windowTitle)
        }
        return WindowConfiguration(title: _resolveAppId())
    }

    public func render(width: CGFloat, height: CGFloat) -> [IPCRenderCommand]? { nil }
    public func onPointerMove(x: CGFloat, y: CGFloat) {}
    public func onPointerButton(button: UInt32, pressed: Bool, x: CGFloat, y: CGFloat) {}
    public func onKey(keycode: UInt32, pressed: Bool) {}
    public func onKeyChar(character: String) {}
    public func onMenuAction(itemId: String) {}
    public func onOpenPanelResult(path: String?) {}
    public func onAppMenus(appName: String, menus: [AppMenu]) {}
    public func onFocusedApp(name: String) {}
    public func onMinimizedApps(appIds: [String]) {}

    /// Default entry point.
    public static func main() {
        nonisolated(unsafe) let app = Self()
        let config = app.configuration
        let appId = _resolveAppId()
        let title = config.title.isEmpty ? appId : config.title
        let usesDeclarativeRendering = app.render(width: 0, height: 0) == nil

        do {
            try app.client.connect(
                appId: appId,
                title: title,
                width: Float(config.width),
                height: Float(config.height),
                role: config.role
            )
        } catch {
            fputs("Failed to connect to compositor: \(error)\n", stderr)
            exit(1)
        }

        // Wire up system actions so apps can launch/restore without touching client.
        let client = app.client
        SystemActions.shared.launchApp = LaunchAppAction { appId in
            client.send(.launchApp(appId: appId))
        }
        SystemActions.shared.restoreApp = RestoreAppAction { appId in
            client.send(.restoreApp(appId: appId))
        }
        SystemActions.shared.sessionReady = SessionReadyAction {
            client.send(.sessionReady)
        }

        if usesDeclarativeRendering {
            // Declarative path: ViewNode → Layout → Flatten → IPC
            guard let windowGroup = app.body as? (any _WindowGroupProtocol) else {
                fputs("App.body must contain a WindowGroup\n", stderr)
                exit(1)
            }
            app.client.onFrameRequest = { w, h in
                let width = CGFloat(w)
                let height = CGFloat(h)
                GeometryReaderRegistry.shared.clear()
                TapRegistry.shared.clear()
                TextFieldRegistry.shared.clear()
                OnceRegistry.shared.resetCounter()
                OnChangeRegistry.shared.resetCounter()
                TagRegistry.shared.clear()
                StateGraph.shared.resetCounter()
                WindowState.shared.update(width: width, height: height)
                // Default opaque background like real SwiftUI windows
                var viewTree = windowGroup.buildViewNode()
                    .background(config.role == .window ? WindowChrome.surface : .clear)
                // Overlay open panel if active
                if let panelOverlay = buildOpenPanelOverlay(width: width, height: height) {
                    viewTree = .zstack(children: [viewTree, panelOverlay])
                }
                let layoutNode = Layout.layout(
                    viewTree,
                    in: LayoutFrame(x: 0, y: 0, width: width, height: height)
                )
                // Propagate .navigationTitle() if it changed.
                if WindowState.shared.titleDidChange(),
                   let newTitle = WindowState.shared.navigationTitle {
                    app.client.send(.setTitle(title: newTitle))
                }
                return CommandFlattener.flatten(layoutNode).map { $0.toIPC() }
            }
            app.client.onPointerButton = { button, pressed, px, py in
                let x = CGFloat(px)
                let y = CGFloat(py)
                // Open panel intercepts clicks when active
                if button == 0 && pressed && handleOpenPanelClick(x: x, y: y, width: CGFloat(app.client.width), height: CGFloat(app.client.height)) {
                    return
                }
                app.onPointerButton(button: button, pressed: pressed, x: x, y: y)
                if button == 0 && pressed {
                    TapRegistry.shared.clear()
                    let cw = CGFloat(app.client.width)
                    let ch = CGFloat(app.client.height)
                    WindowState.shared.update(width: cw, height: ch)
                    let viewTree = windowGroup.buildViewNode()
                    let layoutNode = Layout.layout(
                        viewTree,
                        in: LayoutFrame(x: 0, y: 0, width: cw, height: ch)
                    )
                    if let tapId = layoutNode.hitTestTap(x: x, y: y) {
                        TapRegistry.shared.fire(id: tapId)
                    }
                    // Text field focus
                    TextFieldRegistry.shared.handleClick(x: x, y: y)
                    // Propagate title changes from tap handlers (e.g. navigation).
                    if WindowState.shared.titleDidChange(),
                       let newTitle = WindowState.shared.navigationTitle {
                        app.client.send(.setTitle(title: newTitle))
                    }
                }
            }
            app.client.onPointerMove = { px, py in
                updateOpenPanelMouse(x: CGFloat(px), y: CGFloat(py))
                app.onPointerMove(x: CGFloat(px), y: CGFloat(py))
                let cw = CGFloat(app.client.width)
                let ch = CGFloat(app.client.height)
                HoverRegistry.shared.clear()
                let viewTree = windowGroup.buildViewNode()
                let layoutNode = Layout.layout(
                    viewTree,
                    in: LayoutFrame(x: 0, y: 0, width: cw, height: ch)
                )
                let hitIds = layoutNode.hitTestHover(x: CGFloat(px), y: CGFloat(py))
                HoverRegistry.shared.update(hitIds: hitIds, position: CGPoint(x: CGFloat(px), y: CGFloat(py)))
            }
        } else {
            // Imperative path: app renders IPCRenderCommand directly
            app.client.onFrameRequest = { w, h in
                let width = CGFloat(w)
                let height = CGFloat(h)
                WindowState.shared.update(width: width, height: height)
                var cmds = app.render(width: width, height: height) ?? []
                // Overlay open panel if active
                if let panelOverlay = buildOpenPanelOverlay(width: width, height: height) {
                    let frame = LayoutFrame(x: 0, y: 0, width: width, height: height)
                    let layoutNode = Layout.layout(panelOverlay, in: frame)
                    cmds.append(contentsOf: CommandFlattener.flatten(layoutNode).map { $0.toIPC() })
                }
                return cmds
            }
            app.client.onPointerButton = { button, pressed, px, py in
                if button == 0 && pressed && handleOpenPanelClick(x: CGFloat(px), y: CGFloat(py), width: CGFloat(app.client.width), height: CGFloat(app.client.height)) {
                    return
                }
                app.onPointerButton(button: button, pressed: pressed, x: CGFloat(px), y: CGFloat(py))
            }
            app.client.onPointerMove = { px, py in
                updateOpenPanelMouse(x: CGFloat(px), y: CGFloat(py))
                app.onPointerMove(x: CGFloat(px), y: CGFloat(py))
            }
        }
        app.client.onKey = { keycode, pressed in
            if pressed && handleOpenPanelKey(keycode: keycode) { return }
            // Text field key handling
            if pressed {
                switch keycode {
                case 51: // Backspace
                    TextFieldRegistry.shared.handleBackspace()
                case 48: // Tab
                    TextFieldRegistry.shared.handleTab()
                case 36: // Return
                    TextFieldRegistry.shared.handleReturn()
                default:
                    break
                }
            }
            app.onKey(keycode: keycode, pressed: pressed)
        }
        app.client.onKeyChar = { character in
            // Route to focused text field first
            TextFieldRegistry.shared.handleKeyChar(character)
            app.onKeyChar(character: character)
        }
        app.client.onMenuAction = { itemId in
            app.onMenuAction(itemId: itemId)
        }
        app.client.onOpenPanelResult = { path in
            app.onOpenPanelResult(path: path)
        }
        app.client.onFocusedApp = { name in
            app.onFocusedApp(name: name)
        }
        app.client.onMinimizedApps = { appIds in
            app.onMinimizedApps(appIds: appIds)
        }
        app.client.onAppMenus = { name, menus in
            app.onAppMenus(appName: name, menus: menus)
        }

        fputs("\(title) connected to compositor\n", stderr)
        app.client.runLoop()
        fputs("\(title) disconnected\n", stderr)
    }
}

// MARK: - Internal Helpers

/// Type-erased protocol for extracting WindowGroup info.
@MainActor
protocol _WindowGroupProtocol {
    var windowTitle: String { get }
    func buildViewNode() -> ViewNode
}

extension WindowGroup: _WindowGroupProtocol {
    var windowTitle: String { title }

    func buildViewNode() -> ViewNode {
        _viewToNode(content())
    }
}

/// Convert any View to a ViewNode by recursively evaluating body.
@MainActor
func _viewToNode<V: View>(_ view: V) -> ViewNode {
    _resolve(view)
}

/// Resolve the app ID from the executable name.
func _resolveAppId() -> String {
    "com.clone.\(ProcessInfo.processInfo.processName.lowercased())"
}

// MARK: - IPC Conversion

extension FlatRenderCommand {
    func toIPC() -> IPCRenderCommand {
        let fx = Float(x), fy = Float(y), fw = Float(width), fh = Float(height)
        switch kind {
        case .rect(let color):
            return .rect(x: fx, y: fy, w: fw, h: fh, color: color.toIPC())
        case .roundedRect(let radius, let color):
            return .roundedRect(x: fx, y: fy, w: fw, h: fh,
                                radius: Float(radius), color: color.toIPC())
        case .text(let content, let fontSize, let color, let weight, let isIcon):
            return .text(x: fx, y: fy, content: content, fontSize: Float(fontSize),
                         color: color.toIPC(), weight: weight.toIPC(), isIcon: isIcon)
        case .shadow(let radius, let blur, let color, let offsetX, let offsetY):
            return .shadow(x: fx, y: fy, w: fw, h: fh,
                          radius: Float(radius), blur: Float(blur), color: color.toIPC(),
                          ox: Float(offsetX), oy: Float(offsetY))
        case .pushClip(let radius):
            return .pushClip(x: fx, y: fy, w: fw, h: fh, radius: Float(radius))
        case .popClip:
            return .popClip
        }
    }
}

extension Color {
    func toIPC() -> IPCColor {
        IPCColor(r: Float(r), g: Float(g), b: Float(b), a: Float(a))
    }
}

extension FontWeight {
    func toIPC() -> IPCFontWeight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}

// MARK: - Empty Scene for imperative apps

/// A no-op scene for apps that use imperative rendering instead of a declarative body.
public struct EmptyScene: Scene {
    public typealias Body = _NeverScene
    public var body: _NeverScene { fatalError("EmptyScene is a primitive scene") }
    public init() {}
}
