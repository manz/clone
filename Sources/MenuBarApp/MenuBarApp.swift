import Foundation
import PosixShim
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

private let barHeight: CGFloat = 24
private let menuFontSize: CGFloat = 13
private let iconFontSize: CGFloat = 14
private let menuPadH: CGFloat = 8
private let dropdownW: CGFloat = 220
private let dropdownRowH: CGFloat = 22

// MARK: - Colors

private let barBg = Color(red: 0.96, green: 0.96, blue: 0.96, opacity: 0.85)
private let textColor = Color(red: 0, green: 0, blue: 0, opacity: 1)
private let dimColor = Color(red: 0.4, green: 0.4, blue: 0.4, opacity: 1)
private let highlightBg = Color(red: 0.2, green: 0.47, blue: 0.96, opacity: 1)
private let dropdownBg = Color(red: 0.97, green: 0.97, blue: 0.97, opacity: 1)

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
        socketFd = socket(AF_UNIX, CLONE_SOCK_STREAM, 0)
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
                posix_connect(socketFd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else {
            posix_close(socketFd)
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
            if self.socketFd >= 0 { posix_close(self.socketFd); self.socketFd = -1 }
            self.isConnected = false
        }
        source.resume()
        readSource = source
    }

    func send(_ request: DaemonRequest) {
        guard isConnected, let data = try? WireProtocol.encode(request) else { return }
        data.withUnsafeBytes { ptr in _ = posix_write(socketFd, ptr.baseAddress!, data.count) }
    }

    private func handleReadable() {
        var buf = [UInt8](repeating: 0, count: 65536)
        let bytesRead = posix_read(socketFd, &buf, buf.count)
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

// MARK: - Menu bar action registry

/// Shared registry for menu bar item clicks.
/// The App's onPointerButton reads the last action and sends it via client.
final class MenuBarActionRegistry: @unchecked Sendable {
    static let shared = MenuBarActionRegistry()
    var lastItemId: String? = nil
    var toggleMenuIndex: Int? = nil

    func consume() -> String? {
        let id = lastItemId
        lastItemId = nil
        return id
    }

    func consumeToggle() -> Int? {
        let idx = toggleMenuIndex
        toggleMenuIndex = nil
        return idx
    }
}

// MARK: - Declarative menu bar view

@MainActor func menuBarView(state: MenuBarState, width: CGFloat, height: CGFloat) -> some View {
    let menus = state.appMenus.isEmpty ? defaultMenus : state.appMenus

    return ZStack(alignment: .topLeading) {
        // Bar background — full width, pinned to top
        Rectangle()
            .fill(barBg)
            .frame(width: width, height: barHeight)

        // Bar content
        HStack(spacing: 0) {
            // Apple logo
            Text("\u{F8FF}")
                .font(.system(size: iconFontSize))
                .foregroundColor(textColor)
                .padding(.leading, 12)

            // App name (bold)
            Text(state.focusedAppName)
                .font(.system(size: menuFontSize, weight: .bold))
                .foregroundColor(textColor)
                .padding(.leading, 12)
                .padding(.trailing, 16)

            // Menu titles
            ForEach(Array(menus.enumerated()), id: \.offset) { i, menu in
                menuTitleView(state: state, title: menu.title, index: i)
            }

            Spacer()

            // Now playing
            if let np = state.nowPlaying {
                nowPlayingView(np: np)
                    .padding(.trailing, 12)
            }

            // Clock
            clockView()
                .padding(.trailing, 12)
        }
        .frame(width: width, height: barHeight)

        // Dropdown overlay
        if let openIdx = state.openMenuIndex, openIdx < menus.count {
            dropdownView(state: state, menu: menus[openIdx], menuIndex: openIdx, menus: menus)
        }
    }
    .frame(width: width, height: height)
}

@MainActor func menuTitleView(state: MenuBarState, title: String, index: Int) -> some View {
    let isOpen = state.openMenuIndex == index
    return Text(title)
        .font(.system(size: menuFontSize))
        .foregroundColor(isOpen ? .white : textColor)
        .padding(.horizontal, menuPadH)
        .padding(.vertical, 2)
        .background(
            isOpen
                ? RoundedRectangle(cornerRadius: 4).fill(highlightBg)
                : RoundedRectangle(cornerRadius: 4).fill(Color(red: 0, green: 0, blue: 0, opacity: 0))
        )
        .onTapGesture {
            if state.openMenuIndex == index {
                state.openMenuIndex = nil
            } else {
                state.openMenuIndex = index
            }
        }
}

@MainActor func clockView() -> some View {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    let clock = formatter.string(from: Date())
    return Text(clock)
        .font(.system(size: menuFontSize))
        .foregroundColor(textColor)
}

@MainActor func nowPlayingView(np: NowPlayingInfo) -> some View {
    let artist = np.artist ?? ""
    let title = np.title ?? ""
    let label = artist.isEmpty ? title : "\(artist) — \(title)"
    let isPlaying = (np.playbackRate ?? 0) > 0

    return HStack(spacing: 4) {
        Text("\u{23EE}")
            .font(.system(size: 11))
            .foregroundColor(dimColor)
        Text(isPlaying ? "\u{23F8}" : "\u{23F5}")
            .font(.system(size: 11))
            .foregroundColor(dimColor)
        Text("\u{23ED}")
            .font(.system(size: 11))
            .foregroundColor(dimColor)
        Text(label)
            .font(.system(size: 12))
            .foregroundColor(dimColor)
            .padding(.leading, 8)
    }
}

@MainActor func dropdownView(state: MenuBarState, menu: AppMenu, menuIndex: Int, menus: [AppMenu]) -> some View {
    // Compute x position for the dropdown
    let dropdownX = computeDropdownX(state: state, menuIndex: menuIndex, menus: menus)
    let items = menu.items
    let dropH = CGFloat(items.count) * dropdownRowH + 8

    return VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
            if item.isSeparator {
                Rectangle()
                    .fill(Color(red: 0, green: 0, blue: 0, opacity: 0.08))
                    .frame(height: 1)
                    .padding(.horizontal, 8)
                    .frame(height: dropdownRowH)
            } else {
                dropdownItemView(state: state, item: item)
            }
        }
    }
    .frame(width: dropdownW, height: dropH)
    .background(
        RoundedRectangle(cornerRadius: 6)
            .fill(dropdownBg)
    )
    .padding(.top, barHeight)
    .padding(.leading, dropdownX)
}

@MainActor func dropdownItemView(state: MenuBarState, item: AppMenuItem) -> some View {
    let isHovered = false // Hover handled via onPointerMove + state comparison at frame time
    return HStack(spacing: 0) {
        Text(item.title)
            .font(.system(size: menuFontSize))
            .foregroundColor(isHovered ? .white : textColor)
            .padding(.leading, 12)
        Spacer()
        if let shortcut = item.shortcut {
            Text(shortcut)
                .font(.system(size: 12))
                .foregroundColor(isHovered ? Color(red: 1, green: 1, blue: 1, opacity: 0.7) : dimColor)
                .padding(.trailing, 12)
        }
    }
    .frame(width: dropdownW - 8, height: dropdownRowH)
    .onTapGesture {
        MenuBarActionRegistry.shared.lastItemId = item.id
        state.openMenuIndex = nil
    }
}

func computeDropdownX(state: MenuBarState, menuIndex: Int, menus: [AppMenu]) -> CGFloat {
    let appNameWidth = CGFloat(state.focusedAppName.count) * 7.5
    var x: CGFloat = 12 + 14 + 12 + appNameWidth + 16
    for i in 0..<menuIndex {
        let titleW = CGFloat(menus[i].title.count) * 7.5 + menuPadH * 2
        x += titleW + 4
    }
    return x - menuPadH / 2
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
            menuBarView(state: state, width: 1280, height: 400)
        }
    }

    #if canImport(CloneClient)
    var configuration: WindowConfiguration {
        WindowConfiguration(title: "MenuBar", width: 1280, height: 400, role: .menubar)
    }

    func onFocusedApp(name: String) {
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
        if state.openMenuIndex != nil && y < barHeight {
            let menus = state.appMenus.isEmpty ? defaultMenus : state.appMenus
            let appNameWidth = CGFloat(state.focusedAppName.count) * 7.5
            var mx: CGFloat = 12 + 14 + 12 + appNameWidth + 16
            for (i, menu) in menus.enumerated() {
                let titleW = CGFloat(menu.title.count) * 7.5 + menuPadH * 2
                if x >= mx && x < mx + titleW {
                    state.openMenuIndex = i
                    break
                }
                mx += titleW + 4
            }
        }
    }

    func onPointerButton(button: UInt32, pressed: Bool, x: CGFloat, y: CGFloat) {
        guard button == 0 && pressed else { return }

        // Check if a menu item was tapped (via declarative onTapGesture)
        if let itemId = MenuBarActionRegistry.shared.consume() {
            client.send(.menuAction(itemId: itemId))
        }
    }
    #endif
}
