import Foundation
import SwiftUI
import AppKit
import Combine

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
    let anchorX: CGFloat
    let anchorY: CGFloat
    let items: [MenuItem]
    let targetIndex: Int?
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

// MARK: - Semantic color aliases (NSColor adapts to dark/light on both platforms)

var bgColor: Color { Color(nsColor: .controlBackgroundColor) }
var surfaceColor: Color { Color(nsColor: .unemphasizedSelectedContentBackgroundColor) }
var overlayColor: Color { Color(nsColor: .separatorColor) }
var highlightColor: Color { Color(nsColor: .unemphasizedSelectedContentBackgroundColor).opacity(0.5) }
var selectionColor: Color { Color.accentColor.opacity(0.3) }
var menuBgColor: Color { Color(nsColor: .windowBackgroundColor).opacity(0.95) }
var sidebarBgColor: Color { Color(nsColor: .controlBackgroundColor) }
var textColor: Color { .primary }
var subtleColor: Color { .secondary }
var mutedColor: Color { .gray }
let folderColor: Color = .blue
let codeColor: Color = .orange
let imageColor: Color = .green
var docColor: Color { .secondary }
var menuHoverColor: Color { .blue }
var disabledColor: Color { .gray }
let shadowColor = Color(red: 0, green: 0, blue: 0, opacity: 0.3)

// MARK: - Sidebar favorites

let favorites: [(name: String, path: String, icon: Color)] = [
    ("Home", NSHomeDirectory(), folderColor),
    ("Desktop", (NSHomeDirectory() as NSString).appendingPathComponent("Desktop"), folderColor),
    ("Documents", (NSHomeDirectory() as NSString).appendingPathComponent("Documents"), folderColor),
    ("Downloads", (NSHomeDirectory() as NSString).appendingPathComponent("Downloads"), folderColor),
    ("Applications", "/Applications", Color.purple),
]

// MARK: - State

final class FinderState: ObservableObject {
    @Published var currentPath: String
    @Published var entries: [FileEntry] = []
    var mouseX: CGFloat = 0
    var mouseY: CGFloat = 0

    @Published var selectedIndex: Int?

    var navigationHistory: [String]
    var historyIndex: Int

    @Published var contextMenu: ContextMenu?

    var lastClickTime: Double = 0
    var lastClickIndex: Int?

    var sortOrder: SortOrder = .name

    @Published var infoPanel: InfoPanel?

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

    func handleLeftClick(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        if infoPanel != nil { infoPanel = nil; return }

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

        if y < toolbarHeight { return }

        if x < sidebarWidth {
            let startY = toolbarHeight + 30
            for (i, fav) in favorites.enumerated() {
                let favY = startY + CGFloat(i) * 26
                if y >= favY && y < favY + 26 { navigateTo(fav.path); return }
            }
            return
        }

        let listTop = toolbarHeight + headerHeight
        let listHeight = height - toolbarHeight - headerHeight - statusBarHeight
        if y >= listTop && y < listTop + listHeight {
            let rowIndex = Int((y - listTop) / rowHeight)
            if rowIndex >= 0 && rowIndex < entries.count {
                let now = Date().timeIntervalSince1970
                if lastClickIndex == rowIndex && (now - lastClickTime) < 0.3 {
                    if entries[rowIndex].isDirectory { navigate(to: entries[rowIndex].name) }
                    lastClickTime = 0; lastClickIndex = nil; return
                }
                selectedIndex = rowIndex
                lastClickTime = now; lastClickIndex = rowIndex
            } else { selectedIndex = nil }
        }
    }

    func handleRightClick(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        contextMenu = nil
        let listTop = toolbarHeight + headerHeight
        let listX = sidebarWidth
        let listHeight = height - toolbarHeight - headerHeight - statusBarHeight

        let bgMenu = ContextMenu(anchorX: x, anchorY: y, items: [
            MenuItem(label: "New Folder", action: .newFolder),
            MenuItem(label: "Sort by Name", action: .sortByName),
            MenuItem(label: "Sort by Size", action: .sortBySize),
            MenuItem(label: "Sort by Date", action: .sortByDate),
        ], targetIndex: nil)

        if x >= listX && y >= listTop && y < listTop + listHeight {
            let rowIndex = Int((y - listTop) / rowHeight)
            if rowIndex >= 0 && rowIndex < entries.count {
                let rowY = listTop + CGFloat(rowIndex) * rowHeight
                selectedIndex = rowIndex
                contextMenu = ContextMenu(anchorX: x, anchorY: rowY + rowHeight, items: [
                    MenuItem(label: "Open", action: .open),
                    MenuItem(label: "Get Info", action: .getInfo),
                    MenuItem(label: "Copy", action: .copy),
                    MenuItem(label: "Move to Trash", action: .moveToTrash),
                ], targetIndex: rowIndex)
            } else { contextMenu = bgMenu }
        } else { contextMenu = bgMenu }
    }

    func updateContextMenuHover(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        guard var menu = contextMenu else { return }
        let menuHeight = CGFloat(menu.items.count) * contextMenuItemHeight + 8
        let menuX = min(menu.anchorX, width - contextMenuWidth - 4)
        let menuY = min(menu.anchorY, height - menuHeight - 4)
        if x >= menuX && x < menuX + contextMenuWidth &&
           y >= menuY && y < menuY + menuHeight {
            let itemIndex = Int((y - menuY - 4) / contextMenuItemHeight)
            menu.hoveredItem = (itemIndex >= 0 && itemIndex < menu.items.count) ? itemIndex : nil
        } else { menu.hoveredItem = nil }
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
                infoPanel = InfoPanel(name: entry.name, path: fullPath, kind: kind,
                                      size: formatSize(entry), isDirectory: entry.isDirectory)
            }
        case .sortByName: sortOrder = .name; reload()
        case .sortBySize: sortOrder = .size; reload()
        case .sortByDate: sortOrder = .date; reload()
        case .copy, .moveToTrash, .newFolder: break
        }
    }

    func shortenPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) { return "~" + path.dropFirst(home.count) }
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

@MainActor func navButtonGroup(state: FinderState) -> some View {
    HStack(spacing: 0) {
        Button(action: { state.goBack() }) {
            Image(systemName: "chevron.left")
                .frame(width: 28, height: 22)
        }
        .foregroundColor(state.canGoBack ? textColor : disabledColor)
        Rectangle().fill(overlayColor).frame(width: 1, height: 16)
        Button(action: { state.goForward() }) {
            Image(systemName: "chevron.right")
                .frame(width: 28, height: 22)
        }
        .foregroundColor(state.canGoForward ? textColor : disabledColor)
    }
    .background(
        RoundedRectangle(cornerRadius: 11).fill(surfaceColor)
    )
}

@MainActor func sidebarItemView(name: String, icon: Color, isActive: Bool) -> some View {
    HStack(alignment: .center, spacing: 6) {
        RoundedRectangle(cornerRadius: 4).fill(icon).frame(width: 18, height: 18)
        Text(name).font(.system(size: 13)).foregroundColor(textColor)
        Spacer()
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background(
        RoundedRectangle(cornerRadius: 5)
            .fill(isActive ? selectionColor : .clear)
    )
    .padding(.horizontal, 6)
}

@MainActor func sidebarContentView(state: FinderState) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text("Favorites").font(.system(size: 11, weight: .semibold))
            .foregroundColor(subtleColor)
            .padding(.leading, 14)
            .padding(.top, 10)
        ForEach(Array(favorites.enumerated()), id: \.offset) { _, fav in
            sidebarItemView(
                name: fav.name,
                icon: fav.icon,
                isActive: state.currentPath == fav.path
            ).onTapGesture {
                state.navigateTo(fav.path)
            }
        }
        Spacer()
    }
    .background(sidebarBgColor)
}

@MainActor func columnHeadersView() -> some View {
    ZStack {
        Rectangle().fill(surfaceColor)
        HStack(alignment: .center, spacing: 0) {
            Rectangle().fill(.clear).frame(width: 40, height: 1)
            Text("Name").font(.system(size: 11, weight: .semibold)).foregroundColor(subtleColor)
            Spacer()
            Text("Size").font(.system(size: 11, weight: .semibold)).foregroundColor(subtleColor)
            Rectangle().fill(.clear).frame(width: 20, height: 1)
        }
        VStack { Spacer(); Rectangle().fill(overlayColor).frame(height: 1) }
    }.frame(maxWidth: .infinity, maxHeight: headerHeight)
}

@MainActor func fileRowView(state: FinderState, entry: FinderState.FileEntry, index: Int) -> some View {
    let isSelected = state.selectedIndex == index
    let (iconColor, _) = state.fileKind(entry.name)
    let sizeText = state.formatSize(entry)
    let rowBg: Color = isSelected ? selectionColor : .clear

    return HStack(alignment: .center, spacing: 6) {
        Rectangle().fill(.clear).frame(width: 6, height: 1)
        RoundedRectangle(cornerRadius: 4).fill(iconColor).frame(width: 20, height: 20)
        Text(entry.name).font(.system(size: 13)).foregroundColor(textColor)
        Spacer()
        Text(sizeText).font(.system(size: 11)).foregroundColor(subtleColor)
        Rectangle().fill(.clear).frame(width: 14, height: 1)
    }.frame(maxWidth: .infinity, maxHeight: rowHeight)
    .background(rowBg)
    .contentShape(Rectangle())
    .onTapGesture(count: 2) {
        if entry.isDirectory { state.navigate(to: entry.name) }
    }
    .onTapGesture {
        state.selectedIndex = index
    }
    .contextMenu {
        if entry.isDirectory {
            Button("Open") { state.navigate(to: entry.name) }
        }
        Button("Get Info") {
            let fullPath = (state.currentPath as NSString).appendingPathComponent(entry.name)
            let (_, kind) = state.fileKind(entry.name)
            state.infoPanel = FinderState.InfoPanel(
                name: entry.name, path: fullPath, kind: kind,
                size: state.formatSize(entry), isDirectory: entry.isDirectory
            )
        }
        Divider()
        Button("Copy") { }
        Button("Move to Trash", role: .destructive) { }
    }
}

@MainActor func fileListView(state: FinderState) -> some View {
    List {
        ForEach(Array(state.entries.enumerated()), id: \.offset) { i, entry in
            fileRowView(state: state, entry: entry, index: i)
        }
    }
    .listStyle(.inset(alternatesRowBackgrounds: true))
}

@MainActor func statusBarView(state: FinderState) -> some View {
    let itemCount = state.entries.count
    let label = itemCount == 1 ? "1 item" : "\(itemCount) items"

    return ZStack {
        Rectangle().fill(surfaceColor)
        VStack { Rectangle().fill(overlayColor).frame(height: 1); Spacer() }
        HStack {
            Rectangle().fill(.clear).frame(width: 12, height: 1)
            Text(label).font(.system(size: 11)).foregroundColor(subtleColor)
            Spacer()
        }
    }.frame(maxWidth: .infinity, maxHeight: statusBarHeight)
}

@MainActor func contextMenuItemView(item: MenuItem, isHovered: Bool) -> some View {
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

// TODO: Context menu and info panel need reimplementation as overlays
// rather than imperative positioned views
@MainActor func contextMenuView(menu: ContextMenu, width: CGFloat, height: CGFloat) -> some View {
    let menuHeight = CGFloat(menu.items.count) * contextMenuItemHeight + 8
    let menuX = min(menu.anchorX, width - contextMenuWidth - 4)
    let menuY = min(menu.anchorY, height - menuHeight - 4)

    let itemsStack = VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(menu.items.enumerated()), id: \.offset) { i, item in
            contextMenuItemView(item: item, isHovered: menu.hoveredItem == i)
        }
    }.padding(.vertical, 6)
        .frame(width: contextMenuWidth)

    let menuPanel = ZStack {
        RoundedRectangle(cornerRadius: 8).fill(menuBgColor)
            .frame(width: contextMenuWidth, height: menuHeight)
        itemsStack
    }.frame(width: contextMenuWidth, height: menuHeight)

    let panelWithShadow = menuPanel
        .shadow(color: Color(red: 0, green: 0, blue: 0, opacity: 0.2), radius: 12, x: 0, y: 4)

    let positioned = panelWithShadow
        .padding(EdgeInsets(top: menuY, leading: menuX, bottom: 0, trailing: 0))
        .frame(width: width, height: height)

    return positioned
}

@MainActor func infoPanelView(info: FinderState.InfoPanel, width: CGFloat, height: CGFloat) -> some View {
    let panelW: CGFloat = 280
    let titleBarH: CGFloat = 28
    let contentH: CGFloat = 180
    let panelH = titleBarH + contentH
    let panelX = (width - panelW) / 2
    let panelY = (height - panelH) / 2
    let cornerR: CGFloat = 10

    let iconColor: Color = info.isDirectory ? .blue : .orange

    let titleBar = ZStack {
        Rectangle().fill(surfaceColor).frame(width: panelW, height: titleBarH)
        HStack(alignment: .center, spacing: 0) {
            Rectangle().fill(.clear).frame(width: 10, height: 1)
            RoundedRectangle(cornerRadius: 5).fill(.red).frame(width: 10, height: 10)
            Spacer()
            Text("\(info.name) Info").font(.system(size: 12, weight: .bold)).foregroundColor(.primary)
            Spacer()
            Rectangle().fill(.clear).frame(width: 20, height: 1)
        }.frame(width: panelW, height: titleBarH)
    }.frame(width: panelW, height: titleBarH)

    let content = VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 10).fill(iconColor).frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(info.name).font(.system(size: 14, weight: .bold)).foregroundColor(.primary)
                Text(info.kind).font(.system(size: 12)).foregroundColor(.secondary)
            }
        }
        Rectangle().fill(overlayColor).frame(height: 1)
        infoRow("Kind:", info.kind)
        infoRow("Size:", info.size)
        infoRow("Where:", info.path)
    }.padding(12).frame(width: panelW)

    let windowBody = ZStack {
        RoundedRectangle(cornerRadius: cornerR).fill(bgColor).frame(width: panelW, height: panelH)
        VStack(alignment: .leading, spacing: 0) {
            titleBar
            Rectangle().fill(overlayColor).frame(width: panelW, height: 1)
            content
        }.frame(width: panelW, height: panelH)
    }.frame(width: panelW, height: panelH)

    let shadow = RoundedRectangle(cornerRadius: cornerR)
        .fill(Color(red: 0, green: 0, blue: 0, opacity: 0.25))
        .frame(width: panelW, height: panelH)

    let positioned = ZStack {
            shadow.padding(EdgeInsets(top: 4, leading: 4, bottom: 0, trailing: 0))
            windowBody
        }
        .padding(EdgeInsets(top: panelY, leading: panelX, bottom: 0, trailing: 0))
        .frame(width: width, height: height)

    return positioned
}

@MainActor private func infoRow(_ label: String, _ value: String) -> some View {
    HStack(alignment: .top, spacing: 6) {
        Text(label).font(.system(size: 12)).foregroundColor(.secondary).frame(width: 50)
        Text(value).font(.system(size: 12)).foregroundColor(.primary)
    }
}

@MainActor func finderView(state: FinderState) -> some View {
    NavigationSplitView(sidebarWidth: sidebarWidth, sidebar: {
        sidebarContentView(state: state)
    }, detail: {
        VStack(alignment: .leading, spacing: 0) {
            columnHeadersView()
            fileListView(state: state)
            statusBarView(state: state)
        }
    })
        .toolbar {
            ToolbarItem(placement: .navigation) {
                navButtonGroup(state: state)
            }
            ToolbarItem(placement: .principal) {
                Text(state.shortenPath(state.currentPath))
                    .font(.system(size: 12))
                    .foregroundColor(subtleColor)
            }
        }
        .navigationTitle("Finder — \(state.shortenPath(state.currentPath))")
}

// MARK: - App

@main
struct FinderApp: App {
    @StateObject private var state = FinderState()

    var body: some Scene {
        WindowGroup("Finder") {
            NavigationSplitView {
                List(selection: Binding<String?>(
                    get: { state.currentPath },
                    set: { if let path = $0 { state.navigateTo(path) } }
                )) {
                    Section("Favorites") {
                        ForEach(favorites, id: \.name) { fav in
                            Label(fav.name, systemImage: "folder")
                                .tag(fav.path)
                        }
                    }
                }
                .listStyle(.sidebar)
            } detail: {
                List(state.entries, id: \.name) { entry in
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(state.fileKind(entry.name).0)
                            .frame(width: 20, height: 20)
                        Text(entry.name)
                        Spacer()
                        Text(state.formatSize(entry))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .onTapGesture { state.selectedIndex = state.entries.firstIndex(where: { $0.name == entry.name }) ?? 0 }
                    .contextMenu {
                        if entry.isDirectory {
                            Button("Open") { state.navigate(to: entry.name) }
                        }
                        Button("Get Info") { }
                        Divider()
                        Button("Copy") { }
                        Button("Move to Trash") { }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    navButtonGroup(state: state)
                }
                ToolbarItem(placement: .principal) {
                    Text(state.shortenPath(state.currentPath))
                        .font(.system(size: 12))
                        .foregroundColor(subtleColor)
                }
            }
        }
    }
}
