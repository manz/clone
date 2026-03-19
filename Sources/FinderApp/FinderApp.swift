import Foundation
import SwiftUI

// MARK: - Context menu model

enum MenuAction {
    case open, getInfo, copy, moveToTrash
    case newFolder, sortByName, sortBySize, sortByDate
}

struct MenuItem {
    let label: String
    let action: MenuAction
}

struct ContextMenu {
    let anchorX: CGFloat      // leading edge of the menu
    let anchorY: CGFloat      // top of the row the menu is attached to
    let items: [MenuItem]
    let targetIndex: Int?   // nil = background right-click
    var hoveredItem: Int?
}

enum SortOrder {
    case name, size, date
}

// MARK: - Layout constants

let sidebarWidth: CGFloat = 180
let toolbarHeight: CGFloat = 38
let headerHeight: CGFloat = 24
let rowHeight: CGFloat = 28
let statusBarHeight: CGFloat = 22
let contextMenuWidth: CGFloat = 200
let contextMenuItemHeight: CGFloat = 26

// MARK: - Semantic color aliases

var bgColor: Color { Color(nsColor: .controlBackgroundColor) }
var surfaceColor: Color { Color(nsColor: .gridColor) }
var overlayColor: Color { Color(nsColor: .separatorColor) }
var textColor: Color { .primary }
var subtleColor: Color { .secondary }
var mutedColor: Color { .gray }
var highlightColor: Color { WindowChrome.highlight }
var selectionColor: Color { Color(nsColor: .selectedControlColor) }
let folderColor: Color = .blue
let codeColor: Color = .orange
let imageColor: Color = .green
var docColor: Color { .secondary }
var menuBgColor: Color { WindowChrome.popover }
var menuHoverColor: Color { .blue }
var disabledColor: Color { .gray }
var sidebarBgColor: Color { Color(nsColor: .sidebarBackgroundColor) }
let shadowColor = Color(r: 0, g: 0, b: 0, a: 0.3)

// MARK: - Sidebar favorites

let favorites: [(name: String, path: String, icon: Color)] = [
    ("Home", NSHomeDirectory(), folderColor),
    ("Desktop", (NSHomeDirectory() as NSString).appendingPathComponent("Desktop"), folderColor),
    ("Documents", (NSHomeDirectory() as NSString).appendingPathComponent("Documents"), folderColor),
    ("Downloads", (NSHomeDirectory() as NSString).appendingPathComponent("Downloads"), folderColor),
    ("Applications", "/Applications", Color.purple),
]

// MARK: - State

final class FinderState {
    var currentPath: String
    var entries: [FileEntry] = []
    var mouseX: CGFloat = 0
    var mouseY: CGFloat = 0

    // Selection
    var selectedIndex: Int?

    // Navigation history
    var navigationHistory: [String]
    var historyIndex: Int

    // Context menu
    var contextMenu: ContextMenu?

    // Double-click detection
    var lastClickTime: Double = 0
    var lastClickIndex: Int?

    // Sort
    var sortOrder: SortOrder = .name

    // Get Info panel
    var infoPanel: InfoPanel?

    // Cached window size for hit-testing
    var windowWidth: CGFloat = 700
    var windowHeight: CGFloat = 450

    struct InfoPanel {
        let name: String
        let path: String
        let kind: String
        let size: String
        let isDirectory: Bool
    }

    struct FileEntry {
        let name: String
        let isDirectory: Bool
        let size: UInt64
    }

    init(path: String = NSHomeDirectory()) {
        self.currentPath = path
        self.navigationHistory = [path]
        self.historyIndex = 0
        reload()
    }

    func reload() {
        entries = []
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: currentPath) else { return }

        let withAttrs: [(name: String, isDir: Bool, size: UInt64)] = items.compactMap { name in
            guard !name.hasPrefix(".") else { return nil }
            let fullPath = (currentPath as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: fullPath, isDirectory: &isDir)
            var size: UInt64 = 0
            if !isDir.boolValue {
                size = (try? fm.attributesOfItem(atPath: fullPath)[.size] as? UInt64) ?? 0
            }
            return (name, isDir.boolValue, size)
        }

        let sorted: [(name: String, isDir: Bool, size: UInt64)]
        switch sortOrder {
        case .name:
            sorted = withAttrs.sorted { a, b in
                if a.isDir != b.isDir { return a.isDir }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        case .size:
            sorted = withAttrs.sorted { a, b in
                if a.isDir != b.isDir { return a.isDir }
                return a.size > b.size
            }
        case .date:
            sorted = withAttrs.sorted { a, b in
                if a.isDir != b.isDir { return a.isDir }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        }

        entries = sorted.map { FileEntry(name: $0.name, isDirectory: $0.isDir, size: $0.size) }
    }

    func navigateTo(_ path: String) {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        guard isDir.boolValue else { return }

        currentPath = path
        selectedIndex = nil

        if historyIndex < navigationHistory.count - 1 {
            navigationHistory = Array(navigationHistory.prefix(historyIndex + 1))
        }
        navigationHistory.append(path)
        historyIndex = navigationHistory.count - 1

        reload()
    }

    func navigate(to name: String) {
        let fullPath = (currentPath as NSString).appendingPathComponent(name)
        navigateTo(fullPath)
    }

    func goBack() {
        guard historyIndex > 0 else { return }
        historyIndex -= 1
        currentPath = navigationHistory[historyIndex]
        selectedIndex = nil
        reload()
    }

    func goForward() {
        guard historyIndex < navigationHistory.count - 1 else { return }
        historyIndex += 1
        currentPath = navigationHistory[historyIndex]
        selectedIndex = nil
        reload()
    }

    var canGoBack: Bool { historyIndex > 0 }
    var canGoForward: Bool { historyIndex < navigationHistory.count - 1 }

    // MARK: - File type detection

    func fileKind(_ name: String) -> (color: Color, kind: String) {
        let ext = (name as NSString).pathExtension.lowercased()

        if entries.first(where: { $0.name == name })?.isDirectory == true {
            return (folderColor, "Folder")
        }

        switch ext {
        case "swift", "py", "rs", "go", "ts", "js", "c", "cpp", "h", "m", "java", "rb":
            return (codeColor, "Source Code")
        case "png", "jpg", "jpeg", "gif", "svg", "webp", "ico", "bmp", "tiff":
            return (imageColor, "Image")
        case "md", "txt", "json", "yaml", "yml", "xml", "csv", "toml", "plist":
            return (docColor, "Document")
        default:
            return (mutedColor, "Document")
        }
    }

    // MARK: - Interaction

    func handleLeftClick(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        // Dismiss info panel on any click
        if infoPanel != nil {
            infoPanel = nil
            return
        }

        // If context menu open, hit-test it first
        if let menu = contextMenu {
            let menuHeight = CGFloat(menu.items.count) * contextMenuItemHeight + 8
            let menuX = min(menu.anchorX, width - contextMenuWidth - 4)
            let menuY = min(menu.anchorY, height - menuHeight - 4)

            if x >= menuX && x < menuX + contextMenuWidth &&
               y >= menuY && y < menuY + menuHeight {
                let itemIndex = Int((y - menuY - 4) / contextMenuItemHeight)
                if itemIndex >= 0 && itemIndex < menu.items.count {
                    executeMenuAction(menu.items[itemIndex].action, targetIndex: menu.targetIndex)
                }
            }
            contextMenu = nil
            return
        }

        // Toolbar: back/forward
        if y < toolbarHeight {
            if x >= 12 && x < 40 && canGoBack {
                goBack()
                return
            }
            if x >= 46 && x < 74 && canGoForward {
                goForward()
                return
            }
            return
        }

        // Sidebar
        if x < sidebarWidth {
            let startY = toolbarHeight + 30
            for (i, fav) in favorites.enumerated() {
                let favY = startY + CGFloat(i) * 26
                if y >= favY && y < favY + 26 {
                    navigateTo(fav.path)
                    return
                }
            }
            return
        }

        // File list
        let listTop = toolbarHeight + headerHeight
        let listHeight = height - toolbarHeight - headerHeight - statusBarHeight
        if y >= listTop && y < listTop + listHeight {
            let rowIndex = Int((y - listTop) / rowHeight)
            if rowIndex >= 0 && rowIndex < entries.count {
                let now = Date().timeIntervalSince1970

                // Double-click detection
                if lastClickIndex == rowIndex && (now - lastClickTime) < 0.3 {
                    if entries[rowIndex].isDirectory {
                        navigate(to: entries[rowIndex].name)
                    }
                    lastClickTime = 0
                    lastClickIndex = nil
                    return
                }

                // Single click: select
                selectedIndex = rowIndex
                lastClickTime = now
                lastClickIndex = rowIndex
            } else {
                selectedIndex = nil
            }
        }
    }

    func handleRightClick(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        contextMenu = nil

        let listTop = toolbarHeight + headerHeight
        let listX = sidebarWidth
        let listHeight = height - toolbarHeight - headerHeight - statusBarHeight

        let bgMenu = ContextMenu(
            anchorX: x, anchorY: y,
            items: [
                MenuItem(label: "New Folder", action: .newFolder),
                MenuItem(label: "Sort by Name", action: .sortByName),
                MenuItem(label: "Sort by Size", action: .sortBySize),
                MenuItem(label: "Sort by Date", action: .sortByDate),
            ],
            targetIndex: nil
        )

        if x >= listX && y >= listTop && y < listTop + listHeight {
            let rowIndex = Int((y - listTop) / rowHeight)
            if rowIndex >= 0 && rowIndex < entries.count {
                // Anchor to the row: right side of the name area, top of the row
                let rowY = listTop + CGFloat(rowIndex) * rowHeight
                selectedIndex = rowIndex
                contextMenu = ContextMenu(
                    anchorX: x, anchorY: rowY + rowHeight,
                    items: [
                        MenuItem(label: "Open", action: .open),
                        MenuItem(label: "Get Info", action: .getInfo),
                        MenuItem(label: "Copy", action: .copy),
                        MenuItem(label: "Move to Trash", action: .moveToTrash),
                    ],
                    targetIndex: rowIndex
                )
            } else {
                contextMenu = bgMenu
            }
        } else {
            contextMenu = bgMenu
        }
    }

    func updateContextMenuHover(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        guard var menu = contextMenu else { return }
        let menuHeight = CGFloat(menu.items.count) * contextMenuItemHeight + 8
        let menuX = min(menu.anchorX, width - contextMenuWidth - 4)
        let menuY = min(menu.anchorY, height - menuHeight - 4)

        if x >= menuX && x < menuX + contextMenuWidth &&
           y >= menuY && y < menuY + menuHeight {
            let itemIndex = Int((y - menuY - 4) / contextMenuItemHeight)
            if itemIndex >= 0 && itemIndex < menu.items.count {
                menu.hoveredItem = itemIndex
            } else {
                menu.hoveredItem = nil
            }
        } else {
            menu.hoveredItem = nil
        }
        contextMenu = menu
    }

    func executeMenuAction(_ action: MenuAction, targetIndex: Int?) {
        switch action {
        case .open:
            if let idx = targetIndex, idx < entries.count, entries[idx].isDirectory {
                navigate(to: entries[idx].name)
            }
        case .getInfo:
            if let idx = targetIndex, idx < entries.count {
                let entry = entries[idx]
                let fullPath = (currentPath as NSString).appendingPathComponent(entry.name)
                let (_, kind) = fileKind(entry.name)
                infoPanel = InfoPanel(
                    name: entry.name,
                    path: fullPath,
                    kind: kind,
                    size: formatSize(entry),
                    isDirectory: entry.isDirectory
                )
            }
        case .sortByName:
            sortOrder = .name
            reload()
        case .sortBySize:
            sortOrder = .size
            reload()
        case .sortByDate:
            sortOrder = .date
            reload()
        case .copy, .moveToTrash, .newFolder:
            break
        }
    }

    // MARK: - Helpers

    func shortenPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    func formatSize(_ entry: FileEntry) -> String {
        if entry.isDirectory { return "--" }
        if entry.size < 1024 { return "\(entry.size) B" }
        if entry.size < 1024 * 1024 { return "\(entry.size / 1024) KB" }
        return "\(entry.size / (1024 * 1024)) MB"
    }
}

// MARK: - View builders

func toolbarView(state: FinderState, width: CGFloat) -> some View {
    let backColor: Color = state.canGoBack ? textColor : disabledColor
    let fwdColor: Color = state.canGoForward ? textColor : disabledColor
    let pathText = state.shortenPath(state.currentPath)

    let backBtn = ZStack {
        RoundedRectangle(cornerRadius: 4).fill(overlayColor).frame(width: 28, height: 22)
        Text("<").font(.system(size: 13, weight: .semibold)).foregroundColor(backColor)
    }

    let fwdBtn = ZStack {
        RoundedRectangle(cornerRadius: 4).fill(overlayColor).frame(width: 28, height: 22)
        Text(">").font(.system(size: 13, weight: .semibold)).foregroundColor(fwdColor)
    }

    let bar = HStack(alignment: .center, spacing: 6) {
        backBtn
        fwdBtn
        Text(pathText).font(.system(size: 12)).foregroundColor(subtleColor)
        Spacer()
    }.padding(.leading, 12)

    let border = VStack(alignment: .center, spacing: 0) {
        Spacer()
        Rectangle().fill(overlayColor).frame(height: 1)
    }.frame(width: width, height: toolbarHeight)

    return ZStack {
        Rectangle().fill(surfaceColor).frame(width: width, height: toolbarHeight)
        bar
        border
    }.frame(width: width, height: toolbarHeight)
}

func sidebarItemView(name: String, icon: Color, isActive: Bool, isHovered: Bool) -> some View {
    let bgFill: Color = isActive ? selectionColor : (isHovered ? highlightColor : .clear)

    let bg = RoundedRectangle(cornerRadius: 5).fill(bgFill)
        .frame(width: sidebarWidth - 12, height: 24)

    let content = HStack(alignment: .center, spacing: 6) {
        RoundedRectangle(cornerRadius: 4).fill(icon).frame(width: 18, height: 18)
        Text(name).font(.system(size: 13)).foregroundColor(textColor)
        Spacer()
    }.padding(.leading, 8)

    let item = ZStack {
        bg
        content
    }.frame(width: sidebarWidth - 12, height: 26)

    return item.padding(.leading, 6)
}

func sidebarView(state: FinderState, height: CGFloat) -> some View {
    let header = Text("Favorites").font(.system(size: 11, weight: .semibold))
        .foregroundColor(subtleColor)
        .padding(.leading, 8).padding(.top, 10)

    let favList = VStack(alignment: .leading, spacing: 0) {
        for (i, fav) in favorites.enumerated() {
            let favY = toolbarHeight + 30 + CGFloat(i) * 26
            let isHovered = state.mouseX >= 0 && state.mouseX < sidebarWidth &&
                state.mouseY >= favY && state.mouseY < favY + 26
            sidebarItemView(
                name: fav.name,
                icon: fav.icon,
                isActive: state.currentPath == fav.path,
                isHovered: isHovered
            ).onTapGesture {
                state.navigateTo(fav.path)
            }
        }
    }

    let inner = VStack(alignment: .leading, spacing: 0) {
        header
        Rectangle().fill(.clear).frame(width: sidebarWidth, height: 6)
        favList
        Spacer()
    }.frame(width: sidebarWidth, height: height)

    return ZStack {
        Rectangle().fill(sidebarBgColor).frame(width: sidebarWidth, height: height)
        inner
    }.frame(width: sidebarWidth, height: height)
}

func columnHeadersView(width: CGFloat) -> some View {
    let labels = HStack(alignment: .center, spacing: 0) {
        Rectangle().fill(.clear).frame(width: 40, height: 1)
        Text("Name").font(.system(size: 11, weight: .semibold)).foregroundColor(subtleColor)
        Spacer()
        Text("Size").font(.system(size: 11, weight: .semibold)).foregroundColor(subtleColor)
        Rectangle().fill(.clear).frame(width: 20, height: 1)
    }.frame(width: width, height: headerHeight)

    let border = VStack(alignment: .center, spacing: 0) {
        Spacer()
        Rectangle().fill(overlayColor).frame(height: 1)
    }.frame(width: width, height: headerHeight)

    return ZStack {
        Rectangle().fill(surfaceColor).frame(width: width, height: headerHeight)
        labels
        border
    }.frame(width: width, height: headerHeight)
}

func fileRowView(state: FinderState, entry: FinderState.FileEntry, index: Int, width: CGFloat, listTop: CGFloat) -> some View {
    let rowY = listTop + CGFloat(index) * rowHeight
    let isSelected = state.selectedIndex == index
    let isHovered = state.mouseX >= sidebarWidth && state.mouseX < sidebarWidth + width &&
        state.mouseY >= rowY && state.mouseY < rowY + rowHeight
    let (iconColor, _) = state.fileKind(entry.name)
    let sizeText = state.formatSize(entry)
    let rowBg: Color = isSelected ? selectionColor : (isHovered ? highlightColor : .clear)

    let content = HStack(alignment: .center, spacing: 6) {
        Rectangle().fill(.clear).frame(width: 6, height: 1)
        RoundedRectangle(cornerRadius: 4).fill(iconColor).frame(width: 20, height: 20)
        Text(entry.name).font(.system(size: 13)).foregroundColor(textColor)
        Spacer()
        Text(sizeText).font(.system(size: 11)).foregroundColor(subtleColor)
        Rectangle().fill(.clear).frame(width: 14, height: 1)
    }.frame(width: width, height: rowHeight)

    return ZStack {
        Rectangle().fill(rowBg).frame(width: width, height: rowHeight)
        content
    }.frame(width: width, height: rowHeight)
}

func fileListView(state: FinderState, width: CGFloat, height: CGFloat) -> some View {
    let maxRows = Int(height / rowHeight)
    let listTop = toolbarHeight + headerHeight

    return VStack(alignment: .leading, spacing: 0) {
        for (i, entry) in state.entries.prefix(maxRows).enumerated() {
            fileRowView(state: state, entry: entry, index: i, width: width, listTop: listTop)
        }
        Spacer()
    }.frame(width: width, height: height)
}

func statusBarView(state: FinderState, width: CGFloat) -> some View {
    let itemCount = state.entries.count
    let label = itemCount == 1 ? "1 item" : "\(itemCount) items"

    let topBorder = VStack(alignment: .center, spacing: 0) {
        Rectangle().fill(overlayColor).frame(width: width, height: 1)
        Spacer()
    }.frame(width: width, height: statusBarHeight)

    let text = HStack(alignment: .center, spacing: 0) {
        Rectangle().fill(.clear).frame(width: 12, height: 1)
        Text(label).font(.system(size: 11)).foregroundColor(subtleColor)
        Spacer()
    }.frame(width: width, height: statusBarHeight)

    return ZStack {
        Rectangle().fill(surfaceColor).frame(width: width, height: statusBarHeight)
        topBorder
        text
    }.frame(width: width, height: statusBarHeight)
}

func contextMenuItemView(item: MenuItem, isHovered: Bool) -> some View {
    let fill: Color = isHovered ? menuHoverColor : .clear

    let label = HStack(alignment: .center, spacing: 0) {
        Rectangle().fill(.clear).frame(width: 12, height: 1)
        Text(item.label).font(.system(size: 13)).foregroundColor(textColor)
        Spacer()
    }.frame(width: contextMenuWidth - 8, height: contextMenuItemHeight)

    return ZStack {
        RoundedRectangle(cornerRadius: 4).fill(fill)
            .frame(width: contextMenuWidth - 8, height: contextMenuItemHeight)
        label
    }.frame(width: contextMenuWidth - 8, height: contextMenuItemHeight)
        .padding(.leading, 4)
}

func contextMenuView(menu: ContextMenu, width: CGFloat, height: CGFloat) -> some View {
    let menuHeight = CGFloat(menu.items.count) * contextMenuItemHeight + 8
    let menuX = min(menu.anchorX, width - contextMenuWidth - 4)
    let menuY = min(menu.anchorY, height - menuHeight - 4)

    let itemsStack = VStack(alignment: .leading, spacing: 0) {
        for (i, item) in menu.items.enumerated() {
            contextMenuItemView(item: item, isHovered: menu.hoveredItem == i)
        }
    }.padding(.vertical, 6)
        .frame(width: contextMenuWidth)

    let menuPanel = ZStack {
        RoundedRectangle(cornerRadius: 8).fill(menuBgColor)
            .frame(width: contextMenuWidth, height: menuHeight)
        itemsStack
    }.frame(width: contextMenuWidth, height: menuHeight)

    // Position absolutely with soft shadow
    let panelWithShadow = menuPanel
        .shadow(color: Color(r: 0, g: 0, b: 0, a: 0.2), radius: 12, x: 0, y: 4)

    let positioned = panelWithShadow
        .padding(EdgeInsets(top: menuY, leading: menuX, bottom: 0, trailing: 0))
        .frame(width: width, height: height)

    return positioned
}

func infoPanelView(info: FinderState.InfoPanel, width: CGFloat, height: CGFloat) -> some View {
    let panelW: CGFloat = 280
    let titleBarH: CGFloat = 28
    let contentH: CGFloat = 180
    let panelH = titleBarH + contentH
    let panelX = (width - panelW) / 2
    let panelY = (height - panelH) / 2
    let cornerR: CGFloat = 10

    let iconColor: Color = info.isDirectory ? .blue : .orange

    // Title bar with close dot
    let titleBar = ZStack {
        Rectangle().fill(Color(nsColor: .controlColor)).frame(width: panelW, height: titleBarH)
        HStack(alignment: .center, spacing: 0) {
            Rectangle().fill(.clear).frame(width: 10, height: 1)
            RoundedRectangle(cornerRadius: 5)
                .fill(.red)
                .frame(width: 10, height: 10)
            Spacer()
            Text("\(info.name) Info").font(.system(size: 12, weight: .bold)).foregroundColor(.primary)
            Spacer()
            Rectangle().fill(.clear).frame(width: 20, height: 1)
        }.frame(width: panelW, height: titleBarH)
    }.frame(width: panelW, height: titleBarH)

    // Info content
    let content = VStack(alignment: .leading, spacing: 8) {
        // Header: icon + name
        HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 10).fill(iconColor).frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(info.name).font(.system(size: 14, weight: .bold)).foregroundColor(.primary)
                Text(info.kind).font(.system(size: 12)).foregroundColor(.secondary)
            }
        }
        Rectangle().fill(Color(nsColor: .separatorColor)).frame(height: 1)
        infoRow("Kind:", info.kind)
        infoRow("Size:", info.size)
        infoRow("Where:", info.path)
    }.padding(12).frame(width: panelW)

    // Window body
    let windowBody = ZStack {
        RoundedRectangle(cornerRadius: cornerR).fill(Color(nsColor: .controlBackgroundColor)).frame(width: panelW, height: panelH)
        VStack(alignment: .leading, spacing: 0) {
            titleBar
            Rectangle().fill(Color(nsColor: .separatorColor)).frame(width: panelW, height: 1)
            content
        }.frame(width: panelW, height: panelH)
    }.frame(width: panelW, height: panelH)

    // Shadow
    let shadow = RoundedRectangle(cornerRadius: cornerR)
        .fill(Color(r: 0, g: 0, b: 0, a: 0.25))
        .frame(width: panelW, height: panelH)

    // Position with padding offsets
    let positioned = ZStack {
            shadow.padding(EdgeInsets(top: 4, leading: 4, bottom: 0, trailing: 0))
            windowBody
        }
        .padding(EdgeInsets(top: panelY, leading: panelX, bottom: 0, trailing: 0))
        .frame(width: width, height: height)

    return positioned
}

private func infoRow(_ label: String, _ value: String) -> some View {
    HStack(alignment: .top, spacing: 6) {
        Text(label).font(.system(size: 12)).foregroundColor(.secondary).frame(width: 50)
        Text(value).font(.system(size: 12)).foregroundColor(.primary)
    }
}

func finderView(state: FinderState, width: CGFloat, height: CGFloat) -> some View {
    let listWidth = width - sidebarWidth
    let listHeight = height - toolbarHeight - headerHeight - statusBarHeight
    let sidebarH = height - toolbarHeight
    let mainContent = VStack(alignment: .leading, spacing: 0) {
        toolbarView(state: state, width: width)
        HStack(alignment: .top, spacing: 0) {
            sidebarView(state: state, height: sidebarH).frame(width: sidebarWidth)
            Rectangle().fill(overlayColor).frame(width: 1, height: sidebarH)
            VStack(alignment: .leading, spacing: 0) {
                columnHeadersView(width: listWidth)
                fileListView(state: state, width: listWidth, height: listHeight)
                statusBarView(state: state, width: listWidth)
            }.frame(width: listWidth)
        }
    }

    let mainWithBg = ZStack {
        Rectangle().fill(bgColor).frame(width: width, height: height)
        mainContent
    }.frame(width: width, height: height)

    return ZStack {
        mainWithBg.clipped()
        if let menu = state.contextMenu {
            contextMenuView(menu: menu, width: width, height: height)
        }
        if let info = state.infoPanel {
            infoPanelView(info: info, width: width, height: height)
        }
    }.frame(width: width, height: height)
        .navigationTitle("Finder — \(state.shortenPath(state.currentPath))")
}

// MARK: - App

@main
struct FinderApp: App {
    let state = FinderState()

    var body: some Scene {
        WindowGroup("Finder") {
            finderView(state: state, width: WindowState.shared.width, height: WindowState.shared.height)
        }
    }

    var configuration: WindowConfiguration {
        WindowConfiguration(title: "Finder — ~/", width: 700, height: 450)
    }

    func onPointerMove(x: CGFloat, y: CGFloat) {
        state.mouseX = x
        state.mouseY = y
        state.updateContextMenuHover(x: x, y: y, width: state.windowWidth, height: state.windowHeight)
    }

    func onPointerButton(button: UInt32, pressed: Bool, x: CGFloat, y: CGFloat) {
        guard pressed else { return }
        if button == 0 {
            state.handleLeftClick(x: x, y: y, width: state.windowWidth, height: state.windowHeight)
        } else if button == 1 {
            state.handleRightClick(x: x, y: y, width: state.windowWidth, height: state.windowHeight)
        }
    }

    func onKey(keycode: UInt32, pressed: Bool) {
        guard pressed else { return }
        switch keycode {
        case 42, 51:
            state.goBack()
        case 1:
            if state.infoPanel != nil { state.infoPanel = nil }
            else { state.contextMenu = nil }
        default: break
        }
    }
}
