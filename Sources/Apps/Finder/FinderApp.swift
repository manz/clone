import Foundation
import SwiftUI
import AppKit

// MARK: - Model

struct FileEntry: Identifiable {
    let id: String  // full path
    let name: String
    let isDirectory: Bool
    let size: UInt64
    let ext: String

    var icon: String {
        if isDirectory { return "folder.fill" }
        switch ext {
        case "swift", "py", "rs", "go", "ts", "js", "c", "cpp", "h", "m", "java", "rb": return "file.code"
        case "png", "jpg", "jpeg", "gif", "svg", "webp", "bmp", "tiff": return "file.image"
        case "pdf": return "doc"
        case "md", "txt", "json", "yaml", "yml", "xml", "csv", "toml": return "doc.text"
        default: return "file"
        }
    }

    var iconColor: Color {
        if isDirectory { return .blue }
        switch ext {
        case "swift", "py", "rs", "go", "ts", "js", "c", "cpp", "h", "m", "java", "rb": return .orange
        case "png", "jpg", "jpeg", "gif", "svg", "webp", "bmp", "tiff": return .green
        default: return .secondary
        }
    }

    var formattedSize: String {
        if isDirectory { return "--" }
        if size < 1024 { return "\(size) B" }
        if size < 1024 * 1024 { return "\(size / 1024) KB" }
        return String(format: "%.1f MB", Double(size) / (1024 * 1024))
    }
}

struct SidebarItem: Identifiable {
    let id: String  // path
    let name: String
    let icon: String
    let path: String
}

let sidebarFavorites: [SidebarItem] = [
    SidebarItem(id: NSHomeDirectory(), name: "Home", icon: "house", path: NSHomeDirectory()),
    SidebarItem(id: "desktop", name: "Desktop", icon: "folder",
                path: (NSHomeDirectory() as NSString).appendingPathComponent("Desktop")),
    SidebarItem(id: "documents", name: "Documents", icon: "folder",
                path: (NSHomeDirectory() as NSString).appendingPathComponent("Documents")),
    SidebarItem(id: "downloads", name: "Downloads", icon: "folder",
                path: (NSHomeDirectory() as NSString).appendingPathComponent("Downloads")),
    SidebarItem(id: "applications", name: "Applications", icon: "folder", path: "/Applications"),
]

// MARK: - State

@MainActor
final class FinderState: ObservableObject {
    @Published var currentPath: String
    @Published var entries: [FileEntry] = []
    @Published var selectedEntryId: String?

    private var history: [String]
    private var historyIndex: Int

    init(path: String = NSHomeDirectory()) {
        self.currentPath = path
        self.history = [path]
        self.historyIndex = 0
        reload()
    }

    var canGoBack: Bool { historyIndex > 0 }
    var canGoForward: Bool { historyIndex < history.count - 1 }

    var shortPath: String {
        let home = NSHomeDirectory()
        if currentPath == home { return "~" }
        if currentPath.hasPrefix(home) { return "~" + currentPath.dropFirst(home.count) }
        return currentPath
    }

    var itemCountLabel: String {
        entries.count == 1 ? "1 item" : "\(entries.count) items"
    }

    func reload() {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: currentPath) else {
            entries = []
            return
        }
        entries = names.compactMap { name -> FileEntry? in
            guard !name.hasPrefix(".") else { return nil }
            let fullPath = (currentPath as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: fullPath, isDirectory: &isDir)
            var size: UInt64 = 0
            if !isDir.boolValue {
                size = (try? fm.attributesOfItem(atPath: fullPath)[.size] as? UInt64) ?? 0
            }
            let ext = (name as NSString).pathExtension.lowercased()
            return FileEntry(id: fullPath, name: name, isDirectory: isDir.boolValue, size: size, ext: ext)
        }.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    func navigateTo(_ path: String) {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        guard isDir.boolValue else { return }

        currentPath = path
        selectedEntryId = nil

        // Trim forward history
        if historyIndex < history.count - 1 {
            history = Array(history.prefix(historyIndex + 1))
        }
        history.append(path)
        historyIndex = history.count - 1
        reload()
    }

    func openEntry(_ entry: FileEntry) {
        if entry.isDirectory {
            navigateTo(entry.id)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: entry.id))
        }
    }

    func goBack() {
        guard canGoBack else { return }
        historyIndex -= 1
        currentPath = history[historyIndex]
        selectedEntryId = nil
        reload()
    }

    func goForward() {
        guard canGoForward else { return }
        historyIndex += 1
        currentPath = history[historyIndex]
        selectedEntryId = nil
        reload()
    }
}

// MARK: - Views

struct SidebarView: View {
    @ObservedObject var state: FinderState

    var body: some View {
        List(selection: Binding<String?>(
            get: { state.currentPath },
            set: { if let path = $0 { state.navigateTo(path) } }
        )) {
            Section("Favorites") {
                ForEach(sidebarFavorites) { fav in
                    Label(fav.name, systemImage: fav.icon)
                        .tag(fav.path)
                }
            }
        }
        .listStyle(.sidebar)
    }
}

struct FileRowView: View {
    let entry: FileEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.icon)
                .foregroundColor(entry.iconColor)
                .frame(width: 20, height: 20)
            Text(entry.name)
                .font(.system(size: 13))
            Spacer()
            Text(entry.formattedSize)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : .clear)
        )
    }
}

struct DetailView: View {
    @ObservedObject var state: FinderState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column headers
            HStack(spacing: 0) {
                Text("Name")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.leading, 36)
                Spacer()
                Text("Size")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.trailing, 16)
            }
            .padding(.vertical, 4)
            .background(Color(nsColor: .unemphasizedSelectedContentBackgroundColor))
            Divider()

            // File list
            List {
                ForEach(state.entries) { entry in
                    FileRowView(entry: entry, isSelected: state.selectedEntryId == entry.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            state.selectedEntryId = entry.id
                            if entry.isDirectory {
                                state.openEntry(entry)
                            }
                        }
                        .contextMenu {
                            Button("Open") { state.openEntry(entry) }
                            Button("Get Info") { }
                            Divider()
                            Button("Copy") { }
                            Button("Move to Trash") { }
                        }
                }
            }

            // Status bar
            Divider()
            HStack {
                Text(state.itemCountLabel)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.leading, 12)
                Spacer()
            }
            .frame(height: 22)
            .background(Color(nsColor: .unemphasizedSelectedContentBackgroundColor))
        }
    }
}

struct NavButtons: View {
    @ObservedObject var state: FinderState

    var body: some View {
        HStack(spacing: 0) {
            Button(action: { state.goBack() }) {
                Image(systemName: "chevron.left")
                    .frame(width: 28, height: 22)
            }
            .foregroundColor(state.canGoBack ? .primary : .gray)
            Rectangle().fill(Color(nsColor: .separatorColor)).frame(width: 1, height: 16)
            Button(action: { state.goForward() }) {
                Image(systemName: "chevron.right")
                    .frame(width: 28, height: 22)
            }
            .foregroundColor(state.canGoForward ? .primary : .gray)
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .unemphasizedSelectedContentBackgroundColor))
        )
    }
}

// MARK: - App

@main
struct FinderApp: App {
    @StateObject private var state = FinderState()

    var body: some Scene {
        WindowGroup("Finder") {
            NavigationSplitView {
                SidebarView(state: state)
            } detail: {
                DetailView(state: state)
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    NavButtons(state: state)
                }
                ToolbarItem(placement: .principal) {
                    Text(state.shortPath)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Finder — \(state.shortPath)")
        }
        .commands {
            CommandMenu("File") {
                Button("New Folder") { }
            }
            CommandMenu("Go") {
                Button("Back") { state.goBack() }
                Button("Forward") { state.goForward() }
                Button("Home") { state.navigateTo(NSHomeDirectory()) }
            }
        }
    }
}
