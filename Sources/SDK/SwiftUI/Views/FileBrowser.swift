import Foundation

// MARK: - File Entry Model

/// A file or directory entry for display in file browsers and open panels.
public struct FileEntry: Identifiable, Sendable {
    public let id: String  // full path
    public let name: String
    public let isDirectory: Bool
    public let size: UInt64
    public let ext: String

    public init(id: String, name: String, isDirectory: Bool, size: UInt64, ext: String) {
        self.id = id; self.name = name; self.isDirectory = isDirectory; self.size = size; self.ext = ext
    }

    public var icon: String {
        if isDirectory { return "folder.fill" }
        switch ext {
        case "swift", "py", "rs", "go", "ts", "js", "c", "cpp", "h", "m", "java", "rb": return "file.code"
        case "png", "jpg", "jpeg", "gif", "svg", "webp", "bmp", "tiff": return "file.image"
        case "pdf": return "doc"
        case "md", "txt", "json", "yaml", "yml", "xml", "csv", "toml": return "doc.text"
        default: return "file"
        }
    }

    public var iconColor: Color {
        if isDirectory { return .blue }
        switch ext {
        case "swift", "py", "rs", "go", "ts", "js", "c", "cpp", "h", "m", "java", "rb": return .orange
        case "png", "jpg", "jpeg", "gif", "svg", "webp", "bmp", "tiff": return .green
        default: return .secondary
        }
    }

    public var formattedSize: String {
        if isDirectory { return "--" }
        if size < 1024 { return "\(size) B" }
        if size < 1024 * 1024 { return "\(size / 1024) KB" }
        return String(format: "%.1f MB", Double(size) / (1024 * 1024))
    }
}

// MARK: - File System Scanner

/// Scans a directory and returns sorted FileEntry items.
public enum FileScanner {
    public static func scan(path: String) -> [FileEntry] {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: path) else { return [] }
        return names.compactMap { name -> FileEntry? in
            guard !name.hasPrefix(".") else { return nil }
            let fullPath = (path as NSString).appendingPathComponent(name)
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

    /// Shorten a path for display: replace home directory with ~
    public static func shortPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path == home { return "~" }
        if path.hasPrefix(home) { return "~" + path.dropFirst(home.count) }
        return path
    }
}

// MARK: - File Browser State

/// Shared navigation state for file browsing — used by Finder and NSOpenPanel.
@MainActor
public final class FileBrowserState: ObservableObject {
    @Published public var currentPath: String
    @Published public var entries: [FileEntry] = []
    @Published public var selectedEntryId: String?

    private var history: [String]
    private var historyIndex: Int

    /// Optional filter: only show files matching these extensions (empty = show all).
    public var allowedExtensions: [String] = []

    public init(path: String = NSHomeDirectory()) {
        self.currentPath = path
        self.history = [path]
        self.historyIndex = 0
        reload()
    }

    public var canGoBack: Bool { historyIndex > 0 }
    public var canGoForward: Bool { historyIndex < history.count - 1 }

    public var shortPath: String { FileScanner.shortPath(currentPath) }

    public var itemCountLabel: String {
        entries.count == 1 ? "1 item" : "\(entries.count) items"
    }

    /// The currently selected FileEntry, if any.
    public var selectedEntry: FileEntry? {
        guard let id = selectedEntryId else { return nil }
        return entries.first(where: { $0.id == id })
    }

    public func reload() {
        var scanned = FileScanner.scan(path: currentPath)
        if !allowedExtensions.isEmpty {
            scanned = scanned.filter { entry in
                entry.isDirectory || allowedExtensions.contains(entry.ext)
            }
        }
        entries = scanned
    }

    public func navigateTo(_ path: String) {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        guard isDir.boolValue else { return }

        currentPath = path
        selectedEntryId = nil
        if historyIndex < history.count - 1 {
            history = Array(history.prefix(historyIndex + 1))
        }
        history.append(path)
        historyIndex = history.count - 1
        reload()
    }

    public func goBack() {
        guard canGoBack else { return }
        historyIndex -= 1
        currentPath = history[historyIndex]
        selectedEntryId = nil
        reload()
    }

    public func goForward() {
        guard canGoForward else { return }
        historyIndex += 1
        currentPath = history[historyIndex]
        selectedEntryId = nil
        reload()
    }
}

// MARK: - File Row View

/// A single row in a file list — icon, name, size.
public struct FileRowView: View {
    public let entry: FileEntry
    public let isSelected: Bool

    public init(entry: FileEntry, isSelected: Bool) {
        self.entry = entry; self.isSelected = isSelected
    }

    public var body: some View {
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

// MARK: - File List View

/// Column-header + scrollable file list + status bar. Used by both Finder detail and NSOpenPanel.
public struct FileListView: View {
    @ObservedObject public var state: FileBrowserState
    public var onOpen: ((FileEntry) -> Void)?
    public var onSelect: ((FileEntry) -> Void)?

    public init(state: FileBrowserState, onOpen: ((FileEntry) -> Void)? = nil, onSelect: ((FileEntry) -> Void)? = nil) {
        self.state = state; self.onOpen = onOpen; self.onSelect = onSelect
    }

    public var body: some View {
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

            // File rows
            List {
                ForEach(state.entries) { entry in
                    FileRowView(entry: entry, isSelected: state.selectedEntryId == entry.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            state.selectedEntryId = entry.id
                            onSelect?(entry)
                            if entry.isDirectory {
                                onOpen?(entry)
                            }
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

// MARK: - Sidebar Favorites

/// Standard sidebar favorites for file browsers.
public struct FileBrowserSidebar: View {
    @ObservedObject public var state: FileBrowserState

    public init(state: FileBrowserState) { self.state = state }

    public static let defaultFavorites: [(name: String, icon: String, path: String)] = [
        ("Home", "house", NSHomeDirectory()),
        ("Desktop", "folder", (NSHomeDirectory() as NSString).appendingPathComponent("Desktop")),
        ("Documents", "folder", (NSHomeDirectory() as NSString).appendingPathComponent("Documents")),
        ("Downloads", "folder", (NSHomeDirectory() as NSString).appendingPathComponent("Downloads")),
        ("Applications", "folder", "/Applications"),
    ]

    public var body: some View {
        List(selection: Binding<String?>(
            get: { state.currentPath },
            set: { if let path = $0 { state.navigateTo(path) } }
        )) {
            Section("Favorites") {
                ForEach(Self.defaultFavorites, id: \.path) { fav in
                    Label(fav.name, systemImage: fav.icon)
                        .tag(fav.path)
                }
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Nav Buttons

/// Back/Forward navigation buttons for file browsers.
public struct FileBrowserNavButtons: View {
    @ObservedObject public var state: FileBrowserState

    public init(state: FileBrowserState) { self.state = state }

    public var body: some View {
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
