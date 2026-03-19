import Foundation
import CloneClient
import CloneProtocol

// MARK: - Window Configuration

/// Configuration for the app window.
public struct WindowConfiguration {
    public var title: String
    public var width: Float
    public var height: Float
    public var role: SurfaceRole

    public init(title: String, width: Float = 600, height: Float = 400, role: SurfaceRole = .window) {
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
public protocol App {
    associatedtype Body: Scene
    @SceneBuilder var body: Body { get }
    init()

    /// Window configuration. Default uses the WindowGroup title + 600x400 window role.
    var configuration: WindowConfiguration { get }

    /// The AppClient instance. Override only if you need to send custom messages.
    var client: AppClient { get }

    /// Imperative render — return commands directly. Return nil to use the declarative body.
    func render(width: Float, height: Float) -> [IPCRenderCommand]?

    /// Called on pointer movement.
    func onPointerMove(x: Float, y: Float)

    /// Called on pointer button events.
    func onPointerButton(button: UInt32, pressed: Bool, x: Float, y: Float)

    /// Called on key events.
    func onKey(keycode: UInt32, pressed: Bool)

    /// Called when compositor reports the focused app name (menubar).
    func onFocusedApp(name: String)

    /// Called when compositor reports minimized app IDs (dock).
    func onMinimizedApps(appIds: [String])
}

// MARK: - Default Implementations

/// Shared AppClient singleton for the running app.
private var _sharedClient = AppClient()

extension App {
    public var client: AppClient { _sharedClient }

    public var configuration: WindowConfiguration {
        let scene = body
        if let wg = scene as? (any _WindowGroupProtocol) {
            return WindowConfiguration(title: wg.windowTitle)
        }
        return WindowConfiguration(title: _resolveAppId())
    }

    public func render(width: Float, height: Float) -> [IPCRenderCommand]? { nil }
    public func onPointerMove(x: Float, y: Float) {}
    public func onPointerButton(button: UInt32, pressed: Bool, x: Float, y: Float) {}
    public func onKey(keycode: UInt32, pressed: Bool) {}
    public func onFocusedApp(name: String) {}
    public func onMinimizedApps(appIds: [String]) {}

    /// Default entry point.
    public static func main() {
        let app = Self()
        let config = app.configuration
        let appId = _resolveAppId()
        let title = config.title.isEmpty ? appId : config.title
        let usesDeclarativeRendering = app.render(width: 0, height: 0) == nil

        do {
            try app.client.connect(
                appId: appId,
                title: title,
                width: config.width,
                height: config.height,
                role: config.role
            )
        } catch {
            fputs("Failed to connect to compositor: \(error)\n", stderr)
            exit(1)
        }

        if usesDeclarativeRendering {
            // Declarative path: ViewNode → Layout → Flatten → IPC
            guard let windowGroup = app.body as? (any _WindowGroupProtocol) else {
                fputs("App.body must contain a WindowGroup\n", stderr)
                exit(1)
            }
            app.client.onFrameRequest = { width, height in
                TapRegistry.shared.clear()
                // Default opaque background like real SwiftUI windows
                let viewTree = windowGroup.buildViewNode()
                    .background(config.role == .window ? .surface : .clear)
                let layoutNode = Layout.layout(
                    viewTree,
                    in: LayoutFrame(x: 0, y: 0, width: width, height: height)
                )
                return CommandFlattener.flatten(layoutNode).map { $0.toIPC() }
            }
            app.client.onPointerButton = { button, pressed, x, y in
                app.onPointerButton(button: button, pressed: pressed, x: x, y: y)
                if button == 0 && pressed {
                    TapRegistry.shared.clear()
                    let viewTree = windowGroup.buildViewNode()
                    let layoutNode = Layout.layout(
                        viewTree,
                        in: LayoutFrame(x: 0, y: 0, width: app.client.width, height: app.client.height)
                    )
                    if let hit = layoutNode.hitTest(x: x, y: y),
                       case .onTap(let id, _) = hit.node {
                        TapRegistry.shared.fire(id: id)
                    }
                }
            }
        } else {
            // Imperative path: app renders IPCRenderCommand directly
            app.client.onFrameRequest = { width, height in
                app.render(width: width, height: height) ?? []
            }
            app.client.onPointerButton = { button, pressed, x, y in
                app.onPointerButton(button: button, pressed: pressed, x: x, y: y)
            }
        }

        app.client.onPointerMove = { x, y in
            app.onPointerMove(x: x, y: y)
        }
        app.client.onKey = { keycode, pressed in
            app.onKey(keycode: keycode, pressed: pressed)
        }
        app.client.onFocusedApp = { name in
            app.onFocusedApp(name: name)
        }
        app.client.onMinimizedApps = { appIds in
            app.onMinimizedApps(appIds: appIds)
        }

        fputs("\(title) connected to compositor\n", stderr)
        app.client.runLoop()
        fputs("\(title) disconnected\n", stderr)
    }
}

// MARK: - Internal Helpers

/// Type-erased protocol for extracting WindowGroup info.
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
func _viewToNode<V: View>(_ view: V) -> ViewNode {
    if let node = view as? ViewNode { return node }
    return _viewToNode(view.body)
}

/// Resolve the app ID from the executable name.
func _resolveAppId() -> String {
    "com.clone.\(ProcessInfo.processInfo.processName.lowercased())"
}

// MARK: - IPC Conversion

extension FlatRenderCommand {
    func toIPC() -> IPCRenderCommand {
        switch kind {
        case .rect(let color):
            return .rect(x: x, y: y, w: width, h: height, color: color.toIPC())
        case .roundedRect(let radius, let color):
            return .roundedRect(x: x, y: y, w: width, h: height,
                                radius: radius, color: color.toIPC())
        case .text(let content, let fontSize, let color, let weight, _):
            return .text(x: x, y: y, content: content, fontSize: fontSize,
                         color: color.toIPC(), weight: weight.toIPC())
        case .shadow(let radius, let blur, let color, let offsetX, let offsetY):
            return .shadow(x: x, y: y, w: width, h: height,
                          radius: radius, blur: blur, color: color.toIPC(),
                          ox: offsetX, oy: offsetY)
        case .pushClip(let radius):
            return .pushClip(x: x, y: y, w: width, h: height, radius: radius)
        case .popClip:
            return .popClip
        }
    }
}

extension Color {
    func toIPC() -> IPCColor {
        IPCColor(r: r, g: g, b: b, a: a)
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
