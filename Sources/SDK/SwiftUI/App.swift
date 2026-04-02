import Foundation
import AppKit
import CloneClient
import CloneProtocol
import AvocadoEvents
import CloneLaunchServices

/// Shared AvocadoEvents client for the app's lifetime. Set by App.main().
nonisolated(unsafe) var _sharedAEClient: AvocadoEventsClient?

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

    /// Called when the app is asked to open a file (Clone's equivalent of kAEOpenDocuments).
    func onOpenFile(path: String)

    /// Called when an open-file dialog returns a result.
    func onOpenPanelResult(path: String?)

    /// Called when compositor sends the focused app's menus (for menubar).
    func onAppMenus(appName: String, menus: [AppMenu])

    /// Called when compositor reports the focused app name (menubar).
    func onFocusedApp(name: String)

    /// Called when compositor reports minimized app IDs (dock).
    func onMinimizedWindows(windows: [MinimizedWindowInfo])

    /// Called when compositor reports running apps (dock).
    func onRunningApps(apps: [RunningAppInfo])

    /// Called when compositor sends a window thumbnail (dock).
    func onWindowThumbnail(windowId: UInt64, pngData: Data)
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
        return WindowConfiguration(title: _resolveAppName())
    }

    public func render(width: CGFloat, height: CGFloat) -> [IPCRenderCommand]? { nil }
    public func onPointerMove(x: CGFloat, y: CGFloat) {}
    public func onPointerButton(button: UInt32, pressed: Bool, x: CGFloat, y: CGFloat) {}
    public func onKey(keycode: UInt32, pressed: Bool) {}
    public func onKeyChar(character: String) {}
    public func onMenuAction(itemId: String) {}
    public func onOpenFile(path: String) {}
    public func onOpenPanelResult(path: String?) {}
    public func onAppMenus(appName: String, menus: [AppMenu]) {}
    public func onFocusedApp(name: String) {}
    public func onMinimizedWindows(windows: [MinimizedWindowInfo]) {}
    public func onRunningApps(apps: [RunningAppInfo]) {}
    public func onWindowThumbnail(windowId: UInt64, pngData: Data) {}

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
            logErr("Failed to connect to compositor: \(error)\n")
            exit(1)
        }

        // Connect to avocadoeventsd — shared connection for the app's lifetime.
        let aeClient = AvocadoEventsClient()
        do {
            try aeClient.connect()
            aeClient.register(appId: appId)
            aeClient.onEvent = { @Sendable event in
                DispatchQueue.main.async {
                    switch event {
                    case .openDocuments(let paths):
                        for path in paths { app.onOpenFile(path: path) }
                    case .quit:
                        exit(0)
                    case .activate:
                        app.client.send(.activate)
                    case .launchApp:
                        break
                    }
                }
            }
            DispatchQueue.global().async { aeClient.listen() }
            _sharedAEClient = aeClient
        } catch {
            logErr("Note: could not connect to avocadoeventsd: \(error)\n")
        }

        // Wire up system actions.
        let client = app.client
        SystemActions.shared.launchApp = LaunchAppAction { appId in
            if let ae = _sharedAEClient {
                ae.send(to: "com.clone.launchservicesd", event: .launchApp(bundleIdentifier: appId))
            }
        }
        SystemActions.shared.restoreWindow = RestoreWindowAction { windowId in
            client.send(.restoreWindow(windowId: windowId))
        }
        SystemActions.shared.sessionReady = SessionReadyAction {
            logErr("[App] sessionReady fired, sending to compositor\n")
            client.send(.sessionReady)
        }
        SystemActions.shared.setColorScheme = SetColorSchemeAction { dark in
            client.send(.setColorScheme(dark: dark))
        }
        _openFileHandler = { path in
            DispatchQueue.global().async {
                let lsClient = LaunchServicesClient()
                guard let _ = try? lsClient.connect() else { return }
                guard let reg = lsClient.openFile(path: path) else {
                    lsClient.disconnect()
                    return
                }
                lsClient.disconnect()
                if let ae = _sharedAEClient {
                    ae.send(to: reg.bundleIdentifier, event: .openDocuments(paths: [path]))
                }
            }
            return true
        }

        // App-side renderer — used by all declarative apps
        let appRenderer = AppSideRenderer(client: app.client)

        if usesDeclarativeRendering {
            // Cache last view tree for hover hit-testing (avoids full rebuild on pointer move)
            var _cachedViewTree: ViewNode?
            // Cache last layout node for tap hit-testing (avoids full rebuild on every click)
            var _cachedLayoutNode: LayoutNode?
            // Track sheet presence for compositor surface lifecycle
            var _wasSheetActive = false
            // Cache the sheet dismiss action for backdrop taps
            var _sheetDismissAction: (() -> Void)?

            // Declarative path: ViewNode → Layout → Flatten → IPC
            guard let windowGroup = app.body as? (any _WindowGroupProtocol) else {
                logErr("App.body must contain a WindowGroup\n")
                exit(1)
            }
            // Register app menus with compositor (collected from .commands {} on Scene)
            let appMenus = WindowState.shared.appMenus
            if !appMenus.isEmpty {
                app.client.send(.registerMenus(menus: appMenus))
            }
            // Shared frame-building closure used by both rendering paths
            let buildFrame: (_ width: CGFloat, _ height: CGFloat) -> [IPCRenderCommand] = { width, height in
                LayoutCache.shared.swapFrames()
                GeometryReaderRegistry.shared.clear()
                TapRegistry.shared.resetCounter()
                TextFieldRegistry.shared.resetCounter()
                HoverRegistry.shared.resetCounter()
                OnceRegistry.shared.resetCounter()
                OnChangeRegistry.shared.resetCounter()
                TagRegistry.shared.resetCounter()
                StateGraph.shared.resetCounter()
                ScrollRegistry.shared.resetCounter()
                WindowState.shared.update(width: width, height: height)
                // Default opaque background like real SwiftUI windows
                var viewTree = windowGroup.buildViewNode()
                    .background(config.role == .window ? WindowChrome.surface : .clear)
                // Flush deferred onChange actions after view tree is built
                OnChangeRegistry.shared.flushActions()
                // Prepend toolbar items
                viewTree = prependToolbar(viewTree, role: config.role)
                // Sheet compositor surface lifecycle
                let sheetActive = WindowState.shared.activeSheetContent != nil
                if sheetActive && !_wasSheetActive {
                    let size = WindowState.shared.activeSheetSize ?? CGSize(width: 500, height: 300)
                    client.send(.showSheet(width: Float(size.width), height: Float(size.height)))
                    if case .zstack(_, let children) = WindowState.shared.activeSheetOverlay,
                       let first = children.first,
                       case .onTap(let tapId, _) = first {
                        _sheetDismissAction = { TapRegistry.shared.fire(id: tapId) }
                    }
                } else if !sheetActive && _wasSheetActive {
                    client.send(.dismissSheet)
                    _sheetDismissAction = nil
                    WindowState.shared.compositorSheetActive = false
                }
                _wasSheetActive = sheetActive
                if let sheetOverlay = WindowState.shared.activeSheetOverlay {
                    if WindowState.shared.compositorSheetActive,
                       case .zstack(_, let children) = sheetOverlay,
                       let backdrop = children.first {
                        viewTree = .zstack(children: [viewTree, backdrop])
                    } else {
                        viewTree = .zstack(children: [viewTree, sheetOverlay])
                    }
                }
                _cachedViewTree = viewTree
                if ContextMenuRegistry.shared.isOpen {
                    let menuOverlay = buildContextMenuOverlay(
                        items: ContextMenuRegistry.shared.menuItems,
                        x: ContextMenuRegistry.shared.position.x,
                        y: ContextMenuRegistry.shared.position.y,
                        width: width, height: height
                    )
                    viewTree = .zstack(children: [viewTree, menuOverlay])
                }
                if let panelOverlay = buildOpenPanelOverlay(width: width, height: height) {
                    viewTree = .zstack(children: [viewTree, panelOverlay])
                }
                let layoutNode = Layout.layout(
                    viewTree,
                    in: LayoutFrame(x: 0, y: 0, width: width, height: height)
                )
                // Cache for hit-testing — tap/click uses this instead of rebuilding
                _cachedLayoutNode = layoutNode
                if WindowState.shared.titleDidChange(),
                   let newTitle = WindowState.shared.navigationTitle {
                    app.client.send(.setTitle(title: newTitle))
                }
                // Prepend any pending texture registrations (one-time upload)
                var cmds = ImageTextureCache.shared.drainPending()
                cmds.append(contentsOf: CommandFlattener.flatten(layoutNode).flatMap { $0.toIPCCommands() })
                return cmds
            }

            // App-side rendering: app renders pixels via headless GPU → shared memory
            appRenderer.buildFrame = buildFrame
            // Overlay surfaces need transparent background
            let isOverlay = config.role == .dock || config.role == .menubar || config.role == .loginWindow
            appRenderer.transparentBackground = isOverlay
            // Start immediately — windowCreated was already received during connect()
            appRenderer.start(width: CGFloat(app.client.width), height: CGFloat(app.client.height))
            // Respond to requestFrame — update size if changed (resize), mark dirty
            app.client.onFrameRequest = { w, h in
                appRenderer.resize(width: CGFloat(w), height: CGFloat(h))
                return []
            }
            app.client.onPointerButton = { button, pressed, px, py in
                let x = CGFloat(px)
                let y = CGFloat(py)
                // Open panel intercepts clicks when active
                if button == 0 && pressed && handleOpenPanelClick(x: x, y: y, width: CGFloat(app.client.width), height: CGFloat(app.client.height)) {
                    return
                }
                logErr("[App] pointerButton button=\(button) pressed=\(pressed) x=\(x) y=\(y)\n")
                app.onPointerButton(button: button, pressed: pressed, x: x, y: y)
                // Right-click: open context menu
                if button == 1 && pressed {
                    // Close any open menu first
                    ContextMenuRegistry.shared.close()
                    let cw = CGFloat(app.client.width)
                    let ch = CGFloat(app.client.height)
                    GeometryReaderRegistry.shared.clear()
                    TapRegistry.shared.resetCounter()
                    TextFieldRegistry.shared.resetCounter()
                    HoverRegistry.shared.resetCounter()
                    OnceRegistry.shared.resetCounter()
                    OnChangeRegistry.shared.resetCounter()
                    TagRegistry.shared.resetCounter()
                    StateGraph.shared.resetCounter()
                    ScrollRegistry.shared.resetCounter()
                    WindowState.shared.update(width: cw, height: ch)
                    var viewTree = windowGroup.buildViewNode()
                    OnChangeRegistry.shared.flushActions()
                    viewTree = prependToolbar(viewTree, role: config.role)
                    let layoutNode = Layout.layout(viewTree, in: LayoutFrame(x: 0, y: 0, width: cw, height: ch))
                    if let menuItems = layoutNode.hitTestContextMenu(x: x, y: y) {
                        ContextMenuRegistry.shared.open(items: menuItems, x: x, y: y)
                    }
                }
                // Left-click: close context menu or handle tap
                if button == 0 && pressed {
                    if ContextMenuRegistry.shared.isOpen {
                        ContextMenuRegistry.shared.close()
                    }
                    // Use the cached layout from the last render frame for hit-testing.
                    // No need to rebuild the entire view tree — the render already built
                    // and laid out the correct tree with current tap handler IDs.
                    if let layoutNode = _cachedLayoutNode {
                        switch layoutNode.hitTestTap(x: x, y: y) {
                        case .tap(let id, let hitFrame):
                            let local = CGPoint(x: x - hitFrame.x, y: y - hitFrame.y)
                            TapRegistry.shared.fire(id: id, at: local)
                        case .absorbed, .none:
                            break
                        }
                    }
                    // Text field focus
                    TextFieldRegistry.shared.handleClick(x: x, y: y)
                    // Propagate title changes from tap handlers
                    if WindowState.shared.titleDidChange(),
                       let newTitle = WindowState.shared.navigationTitle {
                        app.client.send(.setTitle(title: newTitle))
                    }
                    appRenderer.setNeedsDisplay()
                }
            }
            app.client.onPointerMove = { px, py in
                updateOpenPanelMouse(x: CGFloat(px), y: CGFloat(py))
                app.onPointerMove(x: CGFloat(px), y: CGFloat(py))
                let cw = CGFloat(app.client.width)
                let ch = CGFloat(app.client.height)
                // Use cached view tree from last frame — don't rebuild on hover
                guard let viewTree = _cachedViewTree else { return }
                let layoutNode = Layout.layout(
                    viewTree,
                    in: LayoutFrame(x: 0, y: 0, width: cw, height: ch)
                )
                let hitPositions = layoutNode.hitTestHover(x: CGFloat(px), y: CGFloat(py))
                HoverRegistry.shared.update(positions: hitPositions)
                appRenderer.setNeedsDisplay()
            }
            // Sheet frame request — compositor asks for sheet render commands
            app.client.onSheetFrameRequest = { w, h in
                WindowState.shared.compositorSheetActive = true
                guard let sheetContent = WindowState.shared.activeSheetContent else { return [] }
                let sheetW = CGFloat(w)
                let sheetH = CGFloat(h)
                let layoutNode = Layout.layout(
                    sheetContent,
                    in: LayoutFrame(x: 0, y: 0, width: sheetW, height: sheetH)
                )
                return CommandFlattener.flatten(layoutNode).flatMap { $0.toIPCCommands() }
            }

            // Sheet backdrop tapped — dismiss the sheet
            app.client.onSheetBackdropTapped = {
                _sheetDismissAction?()
            }

            // Sheet pointer button — hit-test the cached sheet content from last frame.
            // Tap IDs are already registered in TapRegistry from the render pass.
            app.client.onSheetPointerButton = { button, pressed, px, py in
                guard button == 0, pressed else { return }
                guard let sheetContent = WindowState.shared.activeSheetContent else { return }
                let sheetSize = WindowState.shared.activeSheetSize ?? CGSize(width: 500, height: 300)
                let layoutNode = Layout.layout(
                    sheetContent,
                    in: LayoutFrame(x: 0, y: 0, width: sheetSize.width, height: sheetSize.height)
                )
                if case .tap(let id, let hitFrame) = layoutNode.hitTestTap(x: CGFloat(px), y: CGFloat(py)) {
                    let local = CGPoint(x: CGFloat(px) - hitFrame.x, y: CGFloat(py) - hitFrame.y)
                    TapRegistry.shared.fire(id: id, at: local)
                }
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
                    cmds.append(contentsOf: CommandFlattener.flatten(layoutNode).flatMap { $0.toIPCCommands() })
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
            appRenderer.setNeedsDisplay()
        }
        app.client.onKeyChar = { character in
            // Route to focused text field first
            TextFieldRegistry.shared.handleKeyChar(character)
            app.onKeyChar(character: character)
            appRenderer.setNeedsDisplay()
        }
        app.client.onScroll = { dx, dy in
            ScrollRegistry.shared.scroll(deltaX: CGFloat(dx), deltaY: CGFloat(dy), atX: CGFloat(app.client.mouseX), atY: CGFloat(app.client.mouseY))
            appRenderer.setNeedsDisplay()
        }
        app.client.onColorScheme = { dark in
            WindowState.shared.colorScheme = dark ? .dark : .light
            AppearanceManager.shared.current = dark ? .dark : .light
        }
        app.client.onMenuAction = { itemId in
            // Fire declarative .commands action if registered
            if let action = MenuRegistry.shared.actions[itemId] {
                action()
            }
            // Also forward to imperative handler
            app.onMenuAction(itemId: itemId)
        }
        app.client.onOpenFile = { path in
            app.onOpenFile(path: path)
        }
        // Compositor-routed AvocadoEvents (legacy fallback)
        app.client.onAvocadoEvent = { event in
            switch event {
            case .openDocuments(let paths):
                for path in paths { app.onOpenFile(path: path) }
            case .quit:
                exit(0)
            case .activate:
                break
            case .launchApp:
                break // handled by launchservicesd
            }
        }
        app.client.onOpenPanelResult = { path in
            app.onOpenPanelResult(path: path)
        }
        app.client.onFocusedApp = { name in
            app.onFocusedApp(name: name)
        }
        app.client.onMinimizedWindows = { windows in
            app.onMinimizedWindows(windows: windows)
        }
        app.client.onRunningApps = { apps in
            app.onRunningApps(apps: apps)
        }
        app.client.onWindowThumbnail = { windowId, pngData in
            app.onWindowThumbnail(windowId: windowId, pngData: pngData)
        }
        app.client.onAppMenus = { name, menus in
            app.onAppMenus(appName: name, menus: menus)
        }

        logErr("\(title) connected to compositor\n")
        app.client.runLoop()
        logErr("\(title) disconnected\n")
    }
}

/// Build a context menu overlay at the given position.
@MainActor func buildContextMenuOverlay(items: [ViewNode], x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> ViewNode {
    let menuWidth: CGFloat = 200
    let itemHeight: CGFloat = 28
    let menuHeight = CGFloat(items.count) * itemHeight + 12
    let menuX = min(x, width - menuWidth - 8)
    let menuY = min(y, height - menuHeight - 8)

    // Build menu item rows with tap handlers
    let rows: [ViewNode] = items.enumerated().map { (_, item) in
        // Extract label text from the item node
        let label: ViewNode
        if case .onTap(_, let child) = item {
            label = child
        } else {
            label = item
        }

        // Check if it's a divider
        if case .rect(_, let h, _) = label, h == 1 {
            return ViewNode.rect(width: menuWidth - 16, height: 1, fill: Color(white: 0.85))
                .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
        }

        let tapId = TapRegistry.shared.register {
            // Fire the original button action if it had one
            if case .onTap(let origId, _) = item {
                TapRegistry.shared.fire(id: origId)
            }
            ContextMenuRegistry.shared.close()
        }

        return ViewNode.onTap(id: tapId, child:
            ViewNode.frame(width: menuWidth, height: itemHeight, child:
                label.foregroundColor(.primary)
                    .padding(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)))
        )
    }

    let menuContent = ViewNode.vstack(alignment: .leading, spacing: 0, children: rows)
        .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))

    let menuPanel = ViewNode.zstack(children: [
        ViewNode.roundedRect(width: menuWidth, height: menuHeight, radius: 8, fill: Color(white: 0.98)),
        ViewNode.roundedRect(width: menuWidth, height: menuHeight, radius: 8, fill: .clear), // shadow placeholder
        menuContent,
    ])

    // Position the menu
    let positioned = menuPanel
        .padding(EdgeInsets(top: menuY, leading: menuX, bottom: 0, trailing: 0))

    // Invisible backdrop to catch clicks and close the menu
    let backdrop = ViewNode.rect(width: width, height: height, fill: Color(white: 0, opacity: 0.01))
    let backdropTapId = TapRegistry.shared.register {
        ContextMenuRegistry.shared.close()
    }

    return ViewNode.zstack(children: [
        ViewNode.onTap(id: backdropTapId, child: backdrop),
        positioned,
    ])
}

/// Prepend toolbar items to the view tree if any were collected.
@MainActor func prependToolbar(_ viewTree: ViewNode, role: SurfaceRole) -> ViewNode {
    let toolbarItems = WindowState.shared.toolbarItems
    guard !toolbarItems.isEmpty && role == .window else { return viewTree }

    let leftPlacements: Set<ToolbarItemPlacement> = [.navigation, .navigationBarLeading, .topBarLeading, .cancellationAction]
    let centerPlacements: Set<ToolbarItemPlacement> = [.principal]

    let leftItems = toolbarItems.filter { leftPlacements.contains($0.placement) }
    let centerItems = toolbarItems.filter { centerPlacements.contains($0.placement) }
    let rightItems = toolbarItems.filter { !leftPlacements.contains($0.placement) && !centerPlacements.contains($0.placement) }

    var barChildren: [ViewNode] = []

    // Left items
    for item in leftItems {
        barChildren.append(ViewNode.frame(width: nil, height: 28, child: item.node))
    }

    barChildren.append(.spacer(minLength: 0))

    // Center items
    if !centerItems.isEmpty {
        barChildren.append(contentsOf: centerItems.map(\.node))
        barChildren.append(.spacer(minLength: 0))
    }

    // Right items
    for item in rightItems {
        barChildren.append(ViewNode.frame(width: nil, height: 28, child: item.node))
    }

    let toolbarBar = ViewNode.hstack(alignment: .center, spacing: 8, children: barChildren)
        .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
    return .vstack(alignment: .leading, spacing: 0, children: [
        toolbarBar,
        ViewNode.rect(width: nil, height: 1, fill: Color(white: 0.85)),
        viewTree,
    ])
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

/// Resolve the app ID from Bundle.main (when running as .app bundle) or executable name.
func _resolveAppId() -> String {
    if let bundleId = Bundle.main.bundleIdentifier {
        return bundleId
    }
    return "com.clone.\(ProcessInfo.processInfo.processName.lowercased())"
}

/// Resolve the app display name from Bundle.main or executable name.
func _resolveAppName() -> String {
    if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
        return name
    }
    if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String {
        return name
    }
    return ProcessInfo.processInfo.processName
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
        case .text(let content, let fontSize, let color, let weight, let maxWidth, let family):
            return .text(x: fx, y: fy, content: content, fontSize: Float(fontSize),
                         color: color.toIPC(), weight: weight.toIPC(),
                         maxWidth: maxWidth.map { Float($0) }, family: family)
        case .icon(let name, let style, let color):
            return .icon(name: name, style: style.toIPC(),
                        x: fx, y: fy, w: fw, h: fh,
                        color: color.toIPC())
        case .shadow(let radius, let blur, let color, let offsetX, let offsetY):
            return .shadow(x: fx, y: fy, w: fw, h: fh,
                          radius: Float(radius), blur: Float(blur), color: color.toIPC(),
                          ox: Float(offsetX), oy: Float(offsetY))
        case .rasterImage(let textureId, let imgW, let imgH, let rgbaData):
            // Returns image draw command — registerTexture is emitted separately via toIPCCommands()
            return .image(textureId: textureId, x: fx, y: fy, w: fw, h: fh)
        case .pushClip(let radius):
            return .pushClip(x: fx, y: fy, w: fw, h: fh, radius: Float(radius))
        case .popClip:
            return .popClip
        }
    }

    /// Track which texture IDs have already been registered (avoid re-uploading every frame).
    nonisolated(unsafe) private static var registeredTextures: Set<UInt64> = []

    /// Convert to IPC commands — may return multiple (e.g. RegisterTexture + Image).
    func toIPCCommands() -> [IPCRenderCommand] {
        switch kind {
        case .rasterImage(let textureId, let imgW, let imgH, let rgbaData):
            let fx = Float(x), fy = Float(y), fw = Float(width), fh = Float(height)
            if Self.registeredTextures.contains(textureId) {
                // Already uploaded — just draw
                return [.image(textureId: textureId, x: fx, y: fy, w: fw, h: fh)]
            }
            Self.registeredTextures.insert(textureId)
            return [
                .registerTexture(textureId: textureId, width: imgW, height: imgH, rgbaData: rgbaData),
                .image(textureId: textureId, x: fx, y: fy, w: fw, h: fh)
            ]
        default:
            return [toIPC()]
        }
    }
}

extension Color {
    func toIPC() -> IPCColor {
        IPCColor(r: Float(r), g: Float(g), b: Float(b), a: Float(a))
    }
}

extension PhosphorIconStyle {
    func toIPC() -> IPCIconStyle {
        switch self {
        case .regular: return .regular
        case .fill: return .fill
        case .duotone: return .duotone
        case .thin: return .thin
        case .light: return .light
        case .bold: return .bold
        }
    }
}

extension FontWeight {
    func toIPC() -> IPCFontWeight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
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
