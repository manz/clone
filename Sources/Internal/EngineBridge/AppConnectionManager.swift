import Foundation
import SwiftUI
import CloneServer
import CloneProtocol
import CloneLaunchServices

/// A pending file dialog request from an app.
struct FileDialogRequest {
    let wmWindowId: UInt64
    let types: [String]
    var currentPath: String = FileManager.default.currentDirectoryPath
    var entries: [FileDialogEntry] = []
    var selectedIndex: Int = 0
    var mouseY: CGFloat = 0

    mutating func loadDirectory() {
        let fm = FileManager.default
        var result: [FileDialogEntry] = []
        // Add parent directory entry
        if currentPath != "/" {
            result.append(FileDialogEntry(name: "..", isDirectory: true, path: (currentPath as NSString).deletingLastPathComponent))
        }
        if let contents = try? fm.contentsOfDirectory(atPath: currentPath) {
            for name in contents.sorted() where !name.hasPrefix(".") {
                let fullPath = (currentPath as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                fm.fileExists(atPath: fullPath, isDirectory: &isDir)
                result.append(FileDialogEntry(name: name, isDirectory: isDir.boolValue, path: fullPath))
            }
        }
        entries = result
        selectedIndex = 0
    }
}

struct FileDialogEntry {
    let name: String
    let isDirectory: Bool
    let path: String
}

/// Manages external app lifecycle, IPC coordination, and window ID mapping.
@MainActor
final class AppConnectionManager {
    private let server = CompositorServer()
    private var externalWindows: [UInt64: UInt64] = [:] // server windowId → wm windowId
    private var childProcesses: [Process] = []
    private var lsClient: LaunchServicesClient?
    var pendingLaunches: [String] = []
    var pendingRestores: [String] = []
    var pendingMenuActions: [String] = []
    var pendingOpenPanels: [(windowId: UInt64, types: [String])] = []
    var pendingOpenFiles: [String] = []
    private var focusedAppName: String = "Finder"
    private(set) var sessionStarted = false
    private var pendingSessionReady = false
    private var pendingColorScheme: Bool? = nil

    /// Map appId to binary name for launching.
    private let appBinaries: [String: String] = [
        "com.clone.finder": "Finder",
        "com.clone.dock": "Dock",
        "com.clone.menubar": "MenuBar",
        "com.clone.settings": "Settings",
        "com.clone.password": "Password",
        "com.clone.textedit": "TextEdit",
        "com.clone.preview": "Preview",
        "com.clone.loginwindow": "LoginWindow",
    ]

    func start() {
        do {
            try server.start()
            fputs("Compositor server listening on \(compositorSocketPath)\n", stderr)
        } catch {
            fputs("Failed to start compositor server: \(error)\n", stderr)
        }

        server.onLaunchApp = { [weak self] appId in
            self?.pendingLaunches.append(appId)
        }
        server.onRestoreApp = { [weak self] appId in
            self?.pendingRestores.append(appId)
        }
        server.onMenuAction = { [weak self] itemId in
            self?.pendingMenuActions.append(itemId)
        }
        server.onShowOpenPanel = { [weak self] windowId, types in
            self?.pendingOpenPanels.append((windowId, types))
        }
        server.onSetColorScheme = { [weak self] dark in
            self?.pendingColorScheme = dark
        }
        server.onSessionReady = { [weak self] in
            self?.pendingSessionReady = true
        }
        server.onOpenFile = { [weak self] path in
            self?.pendingOpenFiles.append(path)
        }

        // Launch pre-session daemons and LoginWindow
        launchApp("cloned")
        launchApp("keychaind")
        launchApp("launchservicesd")
        launchApp("avocadoeventsd")
        // Connect to launchservicesd after a short delay to let it start
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
            let client = LaunchServicesClient()
            do {
                try client.connect()
                DispatchQueue.main.async { self?.lsClient = client }
                fputs("Connected to launchservicesd\n", stderr)
            } catch {
                fputs("Could not connect to launchservicesd: \(error)\n", stderr)
            }
        }
        launchApp("LoginWindow")
    }

    /// Start the user session — launched after LoginWindow signals sessionReady.
    private func startUserSession() {
        guard !sessionStarted else { return }
        sessionStarted = true
        launchApp("Dock")
        launchApp("MenuBar")
        launchApp("Finder")
    }

    func launchApp(_ name: String, isFullPath: Bool = false) {
        let fm = FileManager.default
        let path: String
        if isFullPath && fm.isExecutableFile(atPath: name) {
            path = name
        } else {
            let candidates = [
                URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().appendingPathComponent(name).path,
                "\(cloneSystemPath)/\(name)",
                "\(cloneApplicationsPath)/\(name).app/Contents/MacOS/\(name)",
                ".build/debug/\(name)",
                "target/debug/\(name)",
            ]
            guard let found = candidates.first(where: { fm.isExecutableFile(atPath: $0) }) else {
                fputs("Could not find \(name) binary\n", stderr)
                return
            }
            path = found
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

    /// Create WindowManager windows for newly connected window-role apps.
    func syncNewApps(windowManager: WindowManager) {
        for app in server.connectedApps {
            if app.appId == "pending" { continue }
            if app.role != .window { continue }  // skip dock, menubar, loginWindow
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
            updateFocusedAppName(windowManager: windowManager)
        }

        // Sync titles from window-role apps
        for app in server.connectedApps where app.role == .window {
            if let wmId = externalWindows[app.windowId],
               let idx = windowManager.windows.firstIndex(where: { $0.id == wmId }) {
                windowManager.windows[idx].title = app.title
            }
        }
    }

    func requestFrames() {
        server.requestFrames()
    }

    func commands(for wmWindowId: UInt64) -> [IPCRenderCommand] {
        guard let serverWid = externalWindowId(for: wmWindowId) else { return [] }
        return server.commands(for: serverWid)
    }

    func externalWindowId(for wmWindowId: UInt64) -> UInt64? {
        externalWindows.first(where: { $0.value == wmWindowId })?.key
    }

    func wmWindowId(for serverWindowId: UInt64) -> UInt64? {
        externalWindows[serverWindowId]
    }

    func notifyResize(wmWindowId: UInt64, window: ManagedWindow) {
        guard let serverWid = externalWindowId(for: wmWindowId) else { return }
        let contentWidth = window.width
        let contentHeight = window.height - WindowChrome.titleBarHeight
        server.sendResize(windowId: serverWid, width: Float(contentWidth), height: Float(contentHeight))
    }

    func syncResizingDimensions(windowManager: WindowManager) {
        guard let wmId = windowManager.resizingWindowId,
              let serverWid = externalWindowId(for: wmId),
              let window = windowManager.windows.first(where: { $0.id == wmId }) else { return }
        let contentWidth = window.width
        let contentHeight = window.height - WindowChrome.titleBarHeight
        server.updateAppDimensions(windowId: serverWid, width: Float(contentWidth), height: Float(contentHeight))
    }

    func processLaunchQueue(windowManager: WindowManager, animationManager: AnimationManager) {
        if pendingSessionReady {
            pendingSessionReady = false
            startUserSession()
        }

        for appId in pendingLaunches {
            if let window = windowManager.windows.first(where: { $0.appId == appId && $0.isVisible && !$0.isMinimized }) {
                windowManager.focus(id: window.id)
                updateFocusedAppName(windowManager: windowManager)
            } else if let window = windowManager.minimizedWindows.first(where: { $0.appId == appId }) {
                animateRestore(windowId: window.id, windowManager: windowManager, animationManager: animationManager)
            } else if lsClient?.launch(bundleIdentifier: appId) != nil {
                // launchservicesd found and spawned the app
            } else if let name = appBinaries[appId] {
                launchApp(name)
            }
        }
        pendingLaunches.removeAll()

        for appId in pendingRestores {
            if let window = windowManager.minimizedWindows.first(where: { $0.appId == appId }) {
                animateRestore(windowId: window.id, windowManager: windowManager, animationManager: animationManager)
            }
        }
        pendingRestores.removeAll()

        // Forward menu actions to the focused app
        if let focusedId = windowManager.focusedWindowId {
            for itemId in pendingMenuActions {
                if itemId == "quit.desktop" {
                    fputs("Quit CloneDesktop requested\n", stderr)
                    exit(0)
                } else if itemId == "app.quit" {
                    terminateFocusedApp(windowManager: windowManager)
                } else {
                    sendMenuAction(wmWindowId: focusedId, itemId: itemId)
                }
            }
        }
        pendingMenuActions.removeAll()

        // Process open-panel requests
        for panel in pendingOpenPanels {
            if let wmId = wmWindowId(for: panel.windowId) {
                pendingFileDialog = FileDialogRequest(wmWindowId: wmId, types: panel.types)
            }
        }
        pendingOpenPanels.removeAll()

        // Process color scheme change
        if let dark = pendingColorScheme {
            pendingColorScheme = nil
            broadcastColorScheme(dark: dark)
        }

        // Process open file requests (NSWorkspace.open flow)
        for path in pendingOpenFiles {
            openFileWithDefaultApp(path)
        }
        pendingOpenFiles.removeAll()
    }

    /// Open a file with its default app via launchservicesd.
    func openFileWithDefaultApp(_ path: String) {
        let ext = (path as NSString).pathExtension.lowercased()
        guard !ext.isEmpty else {
            fputs("openFile: no extension for \(path)\n", stderr)
            return
        }
        guard let reg = lsClient?.defaultApp(forExtension: ext) else {
            fputs("openFile: no app registered for .\(ext)\n", stderr)
            return
        }
        // Launch the app if not already running
        let fm = FileManager.default
        let alreadyRunning = server.connectedApps.contains(where: { $0.appId == reg.bundleIdentifier })
        if !alreadyRunning {
            if fm.isExecutableFile(atPath: reg.executablePath) {
                launchApp(reg.executablePath, isFullPath: true)
            } else {
                launchApp(reg.bundleName)
            }
        }
        // Send openFile to the app (it may take a moment to connect)
        // For now, send to any connected app matching the bundle ID
        for app in server.connectedApps where app.appId == reg.bundleIdentifier {
            app.send(.openFile(path: path))
        }
    }

    /// Active file dialog request (rendered by WindowServer).
    var pendingFileDialog: FileDialogRequest?

    /// Notify the app that its window was closed and clean up the mapping.
    func closeWindow(wmWindowId: UInt64) {
        if let serverWid = externalWindowId(for: wmWindowId) {
            server.sendWindowClosed(windowId: serverWid)
            externalWindows.removeValue(forKey: serverWid)
        }
    }

    /// Send terminate to the focused app (Cmd+Q / Quit menu).
    func terminateFocusedApp(windowManager: WindowManager) {
        guard let wmId = windowManager.focusedWindowId,
              let serverWid = externalWindowId(for: wmId) else { return }
        server.sendTerminate(windowId: serverWid)
        server.handleDisconnect(windowId: serverWid)
        externalWindows.removeValue(forKey: serverWid)
        windowManager.close(id: wmId)
        updateFocusedAppName(windowManager: windowManager)
    }

    func sendPointerMove(wmWindowId: UInt64, localX: Float, localY: Float) {
        guard let serverWid = externalWindowId(for: wmWindowId) else { return }
        server.sendPointerMove(windowId: serverWid, x: localX, y: localY)
    }

    func sendPointerButton(wmWindowId: UInt64, button: UInt32, pressed: Bool, x: Float, y: Float) {
        guard let serverWid = externalWindowId(for: wmWindowId) else { return }
        server.sendPointerButton(windowId: serverWid, button: button, pressed: pressed, x: x, y: y)
    }

    func sendPointerButtonToOverlays(button: UInt32, pressed: Bool, x: Float, y: Float) {
        for app in server.connectedApps where app.role == .dock || app.role == .menubar {
            server.sendPointerButton(windowId: app.windowId, button: button, pressed: pressed, x: x, y: y)
        }
    }

    /// Send input to the LoginWindow (pre-session).
    func sendToLoginWindow(pointerMove x: Float, y: Float) {
        for app in server.connectedApps where app.role == .loginWindow {
            server.sendPointerMove(windowId: app.windowId, x: x, y: y)
        }
    }

    func sendToLoginWindow(pointerButton button: UInt32, pressed: Bool, x: Float, y: Float) {
        for app in server.connectedApps where app.role == .loginWindow {
            server.sendPointerButton(windowId: app.windowId, button: button, pressed: pressed, x: x, y: y)
        }
    }

    func sendToLoginWindow(key keycode: UInt32, pressed: Bool) {
        for app in server.connectedApps where app.role == .loginWindow {
            server.sendKey(windowId: app.windowId, keycode: keycode, pressed: pressed)
        }
    }

    func sendToLoginWindow(keyChar character: String) {
        for app in server.connectedApps where app.role == .loginWindow {
            server.sendKeyChar(windowId: app.windowId, character: character)
        }
    }

    func sendKey(wmWindowId: UInt64, keycode: UInt32, pressed: Bool) {
        guard let serverWid = externalWindowId(for: wmWindowId) else { return }
        server.sendKey(windowId: serverWid, keycode: keycode, pressed: pressed)
    }

    func sendKeyChar(wmWindowId: UInt64, character: String) {
        guard let serverWid = externalWindowId(for: wmWindowId) else { return }
        server.sendKeyChar(windowId: serverWid, character: character)
    }

    func sendScroll(wmWindowId: UInt64, deltaX: Float, deltaY: Float) {
        guard let serverWid = externalWindowId(for: wmWindowId) else { return }
        server.sendScroll(windowId: serverWid, deltaX: deltaX, deltaY: deltaY)
    }

    func updateFocusedAppName(windowManager: WindowManager) {
        if let id = windowManager.focusedWindowId,
           let window = windowManager.windows.first(where: { $0.id == id }) {
            if let serverWid = externalWindowId(for: id),
               let app = server.app(for: serverWid) {
                focusedAppName = displayName(from: app.appId)
            } else {
                focusedAppName = window.title
            }
        } else {
            focusedAppName = "Finder"
        }
    }

    /// Derive display name from appId: query LaunchServices, fall back to known binaries or capitalize.
    private func displayName(from appId: String) -> String {
        if let reg = lsClient?.appInfo(bundleIdentifier: appId) {
            return reg.displayName
        }
        if let known = appBinaries[appId] { return known }
        guard let last = appId.split(separator: ".").last else { return appId }
        return last.prefix(1).uppercased() + last.dropFirst()
    }

    func getFocusedAppName() -> String {
        focusedAppName
    }

    func sendSystemState(mouseX: CGFloat, mouseY: CGFloat, minimizedAppIds: [String], focusedWmWindowId: UInt64?) {
        // Get focused app's menus, prepend the system app menu with Quit
        var focusedMenus: [AppMenu] = []
        if let wmId = focusedWmWindowId,
           let serverWid = externalWindowId(for: wmId) {
            focusedMenus = server.menus(for: serverWid)
        }
        var appMenuItems: [AppMenuItem] = []
        if focusedAppName != "Finder" {
            appMenuItems.append(AppMenuItem(id: "app.quit", title: "Quit \(focusedAppName)", shortcut: "⌘Q"))
        }
        let appMenu = AppMenu(title: focusedAppName, items: appMenuItems)
        focusedMenus.insert(appMenu, at: 0)

        for app in server.connectedApps {
            switch app.role {
            case .dock:
                app.send(.minimizedApps(appIds: minimizedAppIds))
                app.send(.pointerMove(x: Float(mouseX), y: Float(mouseY)))
            case .menubar:
                app.send(.focusedApp(name: focusedAppName))
                app.send(.appMenus(appName: focusedAppName, menus: focusedMenus))
            case .window, .loginWindow, .service:
                break
            }
        }
    }

    /// Broadcast color scheme to all connected apps.
    func broadcastColorScheme(dark: Bool) {
        for app in server.connectedApps {
            app.send(.colorScheme(dark: dark))
        }
    }

    /// Forward a menu action from the menubar to the focused app.
    func sendMenuAction(wmWindowId: UInt64, itemId: String) {
        guard let serverWid = externalWindowId(for: wmWindowId) else { return }
        server.sendMenuAction(windowId: serverWid, itemId: itemId)
    }

    // MARK: - Sheet surface forwarding

    func sheetSize(for wmWindowId: UInt64) -> (width: Float, height: Float)? {
        guard let serverWid = externalWindowId(for: wmWindowId) else { return nil }
        return server.sheetSize(for: serverWid)
    }

    func sheetCommands(for wmWindowId: UInt64) -> [IPCRenderCommand] {
        guard let serverWid = externalWindowId(for: wmWindowId) else { return [] }
        return server.sheetCommands(for: serverWid)
    }

    func sendSheetBackdropTapped(wmWindowId: UInt64) {
        guard let serverWid = externalWindowId(for: wmWindowId) else { return }
        server.sendSheetBackdropTapped(windowId: serverWid)
    }

    func sendSheetPointerButton(wmWindowId: UInt64, button: UInt32, pressed: Bool, x: Float, y: Float) {
        guard let serverWid = externalWindowId(for: wmWindowId) else { return }
        server.sendSheetPointerButton(windowId: serverWid, button: button, pressed: pressed, x: x, y: y)
    }

    /// Forward an open-panel result to an app.
    func sendOpenPanelResult(wmWindowId: UInt64, path: String?) {
        guard let serverWid = externalWindowId(for: wmWindowId) else { return }
        server.sendOpenPanelResult(windowId: serverWid, path: path)
    }

    /// Returns overlay surfaces (dock + menubar) for compositing.
    func overlaySurfaces(screenWidth: CGFloat, screenHeight: CGFloat, windowSurfaceBase: UInt64) -> [SurfaceFrame] {
        var frames: [SurfaceFrame] = []
        for app in server.connectedApps {
            if app.role == .loginWindow && sessionStarted { continue }
            guard app.role == .dock || app.role == .menubar || app.role == .loginWindow else { continue }
            let surfaceId = windowSurfaceBase + app.windowId + 10000
            let ipcCommands = app.getCommands()
            if !ipcCommands.isEmpty {
                let engineCommands = ipcCommands.map { Bridge.offsetIpcCommand($0, dy: 0) }
                frames.append(SurfaceFrame(
                    desc: SurfaceDesc(
                        surfaceId: surfaceId,
                        x: 0, y: 0,
                        width: Float(screenWidth), height: Float(screenHeight),
                        cornerRadius: 0, opacity: 1
                    ),
                    commands: engineCommands
                ))
            }
        }
        return frames
    }

    /// Resolve a file dialog by sending the result to the requesting app and clearing the dialog.
    func resolveFileDialog(path: String?) {
        guard let dialog = pendingFileDialog else { return }
        sendOpenPanelResult(wmWindowId: dialog.wmWindowId, path: path)
        pendingFileDialog = nil
    }

    private func animateRestore(windowId: UInt64, windowManager: WindowManager, animationManager: AnimationManager) {
        guard let window = windowManager.windows.first(where: { $0.id == windowId }) else { return }
        let iconIndex = Dock.iconIndex(for: window.appId) ?? 0
        let from = Dock.iconRect(index: iconIndex, screenWidth: windowManager.screenWidth, screenHeight: windowManager.screenHeight)
        let to = AnimRect(x: window.x, y: window.y, w: window.width, h: window.height)
        windowManager.unminimize(id: windowId)
        animationManager.startRestore(windowId: windowId, from: from, to: to)
    }
}
