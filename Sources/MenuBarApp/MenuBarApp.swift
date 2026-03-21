import Foundation
import SwiftUI
import CloneProtocol
import CloneClient

final class MenuBarState {
    var focusedAppName = "Finder"
    var nowPlaying: NowPlayingInfo?
    var appMenus: [AppMenu] = []
    var openMenuIndex: Int? = nil
    var mouseX: CGFloat = 0
    var mouseY: CGFloat = 0
}

/// Default menus when apps don't register their own.
let defaultMenus: [AppMenu] = [
    AppMenu(title: "File", items: [
        AppMenuItem(id: "file.new", title: "New", shortcut: "⌘N"),
        AppMenuItem(id: "file.open", title: "Open...", shortcut: "⌘O"),
        AppMenuItem.separator(),
        AppMenuItem(id: "file.close", title: "Close Window", shortcut: "⌘W"),
    ]),
    AppMenu(title: "Edit", items: [
        AppMenuItem(id: "edit.undo", title: "Undo", shortcut: "⌘Z"),
        AppMenuItem(id: "edit.redo", title: "Redo", shortcut: "⇧⌘Z"),
        AppMenuItem.separator(),
        AppMenuItem(id: "edit.cut", title: "Cut", shortcut: "⌘X"),
        AppMenuItem(id: "edit.copy", title: "Copy", shortcut: "⌘C"),
        AppMenuItem(id: "edit.paste", title: "Paste", shortcut: "⌘V"),
    ]),
    AppMenu(title: "View", items: []),
    AppMenu(title: "Window", items: []),
    AppMenu(title: "Help", items: []),
]

// MARK: - Layout constants

private let barHeight: Float = 24
private let fontSize: Float = 13
private let iconFontSize: Float = 14
private let menuPadH: Float = 8
private let dropdownW: Float = 220
private let dropdownRowH: Float = 22

// MARK: - Compute menu positions

struct MenuPos {
    let title: String
    let x: Float
    let width: Float
    let index: Int
}

func computeMenuPositions(state: MenuBarState) -> [MenuPos] {
    let menus = state.appMenus.isEmpty ? defaultMenus : state.appMenus
    // Apple logo ~14px + pad 12 + app name + gap
    let appNameWidth = Float(state.focusedAppName.count) * 7.5
    var x: Float = 12 + 14 + 12 + appNameWidth + 16
    var result: [MenuPos] = []
    for (i, menu) in menus.enumerated() {
        let titleW = Float(menu.title.count) * 7.5 + menuPadH * 2
        result.append(MenuPos(title: menu.title, x: x, width: titleW, index: i))
        x += titleW + 4
    }
    return result
}

// MARK: - Daemon client (for now-playing)

final class MenuBarDaemonClient: @unchecked Sendable {
    private var socketFd: Int32 = -1
    private var readBuffer = Data()
    private var readSource: DispatchSourceRead?
    private let ioQueue = DispatchQueue(label: "clone.menubar.daemon", qos: .userInitiated)
    private let lock = NSLock()
    private(set) var isConnected = false

    var onNowPlayingChanged: ((NowPlayingInfo?) -> Void)?

    func connect() {
        socketFd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketFd >= 0 else { return }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        daemonSocketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) { pathPtr in
                pathPtr.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
                    _ = strlcpy(dest, ptr, 104)
                }
            }
        }

        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.connect(socketFd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else {
            Darwin.close(socketFd)
            socketFd = -1
            return
        }

        isConnected = true
        let flags = fcntl(socketFd, F_GETFL)
        _ = fcntl(socketFd, F_SETFL, flags | O_NONBLOCK)
        send(.observe)

        let source = DispatchSource.makeReadSource(fileDescriptor: socketFd, queue: ioQueue)
        source.setEventHandler { [weak self] in self?.handleReadable() }
        source.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.socketFd >= 0 { Darwin.close(self.socketFd); self.socketFd = -1 }
            self.isConnected = false
        }
        source.resume()
        readSource = source
    }

    func send(_ request: DaemonRequest) {
        guard isConnected, let data = try? WireProtocol.encode(request) else { return }
        data.withUnsafeBytes { ptr in _ = Darwin.write(socketFd, ptr.baseAddress!, data.count) }
    }

    private func handleReadable() {
        var buf = [UInt8](repeating: 0, count: 65536)
        let bytesRead = Darwin.read(socketFd, &buf, buf.count)
        guard bytesRead > 0 else { readSource?.cancel(); readSource = nil; isConnected = false; return }

        lock.lock()
        readBuffer.append(contentsOf: buf[0..<bytesRead])
        while let (msg, consumed) = WireProtocol.decode(DaemonResponse.self, from: readBuffer) {
            readBuffer = readBuffer.subdata(in: consumed..<readBuffer.count)
            lock.unlock()
            if case .nowPlayingChanged(let info) = msg { onNowPlayingChanged?(info) }
            lock.lock()
        }
        lock.unlock()
    }
}

// MARK: - Imperative renderer

func renderMenuBar(state: MenuBarState, width: Float, height: Float, daemonClient: MenuBarDaemonClient?) -> [IPCRenderCommand] {
    var cmds: [IPCRenderCommand] = []
    let barBg = IPCColor(r: 0.96, g: 0.96, b: 0.96, a: 0.85)
    let textColor = IPCColor(r: 0, g: 0, b: 0, a: 1)
    let dimColor = IPCColor(r: 0.4, g: 0.4, b: 0.4, a: 1)
    let highlightBg = IPCColor(r: 0.2, g: 0.47, b: 0.96, a: 1)
    let white = IPCColor(r: 1, g: 1, b: 1, a: 1)
    let dropdownBg = IPCColor(r: 0.97, g: 0.97, b: 0.97, a: 1)
    let dropdownShadow = IPCColor(r: 0, g: 0, b: 0, a: 0.15)

    // Bar background
    cmds.append(.rect(x: 0, y: 0, w: width, h: barHeight, color: barBg))

    // Apple logo
    let logoX: Float = 12
    cmds.append(.text(x: logoX, y: 5, content: "\u{F8FF}", fontSize: iconFontSize, color: textColor, weight: .regular))

    // App name (bold)
    let appNameX = logoX + 14 + 12
    cmds.append(.text(x: appNameX, y: 5, content: state.focusedAppName, fontSize: fontSize, color: textColor, weight: .bold))

    // Menu titles
    let positions = computeMenuPositions(state: state)
    for pos in positions {
        let isOpen = state.openMenuIndex == pos.index
        if isOpen {
            cmds.append(.rect(x: pos.x - menuPadH / 2, y: 1, w: pos.width, h: barHeight - 2, color: highlightBg))
            cmds.append(.text(x: pos.x + menuPadH / 2, y: 5, content: pos.title, fontSize: fontSize, color: white, weight: .regular))
        } else {
            cmds.append(.text(x: pos.x + menuPadH / 2, y: 5, content: pos.title, fontSize: fontSize, color: textColor, weight: .regular))
        }
    }

    // Clock (right-aligned)
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    let clock = formatter.string(from: Date())
    let clockX = width - 50
    cmds.append(.text(x: clockX, y: 5, content: clock, fontSize: fontSize, color: textColor, weight: .regular))

    // Now playing (before clock)
    if let np = state.nowPlaying {
        let artist = np.artist ?? ""
        let title = np.title ?? ""
        let label = artist.isEmpty ? title : "\(artist) — \(title)"
        let isPlaying = (np.playbackRate ?? 0) > 0
        let npX = clockX - Float(label.count) * 7 - 80
        cmds.append(.text(x: npX, y: 5, content: "\u{23EE}", fontSize: 11, color: dimColor, weight: .regular))
        cmds.append(.text(x: npX + 16, y: 5, content: isPlaying ? "\u{23F8}" : "\u{23F5}", fontSize: 11, color: dimColor, weight: .regular))
        cmds.append(.text(x: npX + 32, y: 5, content: "\u{23ED}", fontSize: 11, color: dimColor, weight: .regular))
        cmds.append(.text(x: npX + 52, y: 5, content: label, fontSize: 12, color: dimColor, weight: .regular))
    }

    // Dropdown
    if let openIdx = state.openMenuIndex {
        let menus = state.appMenus.isEmpty ? defaultMenus : state.appMenus
        guard openIdx < menus.count else { return cmds }
        let menu = menus[openIdx]
        let menuX = positions[openIdx].x - menuPadH / 2
        let items = menu.items
        let dropH = Float(items.count) * dropdownRowH + 8

        // Shadow
        cmds.append(.shadow(x: menuX, y: barHeight, w: dropdownW, h: dropH, radius: 6, blur: 8, color: dropdownShadow, ox: 0, oy: 2))
        // Background
        cmds.append(.roundedRect(x: menuX, y: barHeight, w: dropdownW, h: dropH, radius: 6, color: dropdownBg))

        var itemY = barHeight + 4
        for item in items {
            if item.isSeparator {
                cmds.append(.rect(x: menuX + 8, y: itemY + dropdownRowH / 2 - 0.5, w: dropdownW - 16, h: 1, color: IPCColor(r: 0, g: 0, b: 0, a: 0.08)))
                itemY += dropdownRowH
                continue
            }

            let isHovered = state.mouseX >= CGFloat(menuX)
                && state.mouseX < CGFloat(menuX + dropdownW)
                && state.mouseY >= CGFloat(itemY)
                && state.mouseY < CGFloat(itemY + dropdownRowH)

            if isHovered {
                cmds.append(.roundedRect(x: menuX + 4, y: itemY, w: dropdownW - 8, h: dropdownRowH, radius: 4, color: highlightBg))
            }

            let titleColor = isHovered ? white : textColor
            cmds.append(.text(x: menuX + 12, y: itemY + 3, content: item.title, fontSize: fontSize, color: titleColor, weight: .regular))

            if let shortcut = item.shortcut {
                let shortcutX = menuX + dropdownW - 12 - Float(shortcut.count) * 7
                let shortcutColor = isHovered ? IPCColor(r: 1, g: 1, b: 1, a: 0.7) : dimColor
                cmds.append(.text(x: shortcutX, y: itemY + 3, content: shortcut, fontSize: 12, color: shortcutColor, weight: .regular))
            }

            itemY += dropdownRowH
        }
    }

    return cmds
}

// MARK: - App

@main
struct MenuBarApp: App {
    let state = MenuBarState()
    let daemonClient = MenuBarDaemonClient()

    init() {
        daemonClient.onNowPlayingChanged = { [state] info in
            state.nowPlaying = info
        }
        daemonClient.connect()
    }

    var body: some Scene {
        WindowGroup("MenuBar") {
            Text("")  // placeholder — imperative render used
        }
    }

    var configuration: WindowConfiguration {
        WindowConfiguration(title: "MenuBar", width: 1280, height: 400, role: .menubar)
    }

    func render(width: CGFloat, height: CGFloat) -> [IPCRenderCommand]? {
        renderMenuBar(state: state, width: Float(width), height: Float(height), daemonClient: daemonClient)
    }

    func onFocusedApp(name: String) {
        // Only close menus when the focused app actually changes
        if state.focusedAppName != name {
            state.focusedAppName = name
            state.openMenuIndex = nil
        }
    }

    func onAppMenus(appName: String, menus: [AppMenu]) {
        if state.appMenus != menus {
            state.appMenus = menus
        }
    }

    func onPointerMove(x: CGFloat, y: CGFloat) {
        state.mouseX = x
        state.mouseY = y

        // If a menu is open, hovering over another title switches menus
        if state.openMenuIndex != nil && y < CGFloat(barHeight) {
            let positions = computeMenuPositions(state: state)
            for pos in positions {
                if Float(x) >= pos.x && Float(x) < pos.x + pos.width {
                    state.openMenuIndex = pos.index
                    break
                }
            }
        }
    }

    func onPointerButton(button: UInt32, pressed: Bool, x: CGFloat, y: CGFloat) {
        guard button == 0 && pressed else { return }

        // Click on menu bar title area
        if y < CGFloat(barHeight) {
            let positions = computeMenuPositions(state: state)
            for pos in positions {
                if Float(x) >= pos.x && Float(x) < pos.x + pos.width {
                    if state.openMenuIndex == pos.index {
                        state.openMenuIndex = nil
                    } else {
                        state.openMenuIndex = pos.index
                    }
                    return
                }
            }
            state.openMenuIndex = nil
            return
        }

        // Click on dropdown item
        if let openIdx = state.openMenuIndex {
            let menus = state.appMenus.isEmpty ? defaultMenus : state.appMenus
            guard openIdx < menus.count else { return }
            let positions = computeMenuPositions(state: state)
            let menuX = positions[openIdx].x - menuPadH / 2

            if Float(x) >= menuX && Float(x) < menuX + dropdownW {
                let items = menus[openIdx].items.filter { !$0.isSeparator }
                var itemY = barHeight + 4
                for item in items {
                    if Float(y) >= itemY && Float(y) < itemY + dropdownRowH {
                        client.send(.menuAction(itemId: item.id))
                        state.openMenuIndex = nil
                        return
                    }
                    itemY += dropdownRowH
                }
            }
            state.openMenuIndex = nil
        }
    }
}
