import Foundation

// MARK: - NSSavePanel

/// Base panel for file save/open dialogs. On Clone, panels render inside the app's
/// own window frame using SwiftUI views — the app owns the UI, not the compositor.
open class NSSavePanel {
    public enum Response: Int, Sendable {
        case OK = 1
        case cancel = 0
    }

    /// The URL selected by the user (nil until a selection is made).
    public var url: URL?

    /// Allowed file type extensions (e.g. ["txt", "swift", "json"]).
    public var allowedContentTypes: [String] = []

    /// The title displayed at the top of the panel.
    public var title: String? = nil

    /// Starting directory.
    public var directoryURL: URL? = nil

    /// Whether the panel is currently being shown.
    public private(set) var isVisible: Bool = false

    public init() {}

    /// Show the panel. The completion handler fires on the main thread when the user picks a file or cancels.
    public func begin(completionHandler: @escaping @MainActor (Response) -> Void) {
        self.completionHandler = completionHandler
        isVisible = true
        // Load the initial directory
        let startPath = directoryURL?.path ?? FileManager.default.currentDirectoryPath
        panelState.currentPath = startPath
        panelState.loadDirectory()
        // Register globally so the app's event loop can drive the panel
        NSSavePanel._activePanel = self
    }

    /// Cancel the panel programmatically.
    @MainActor public func cancel() {
        isVisible = false
        NSSavePanel._activePanel = nil
        completionHandler?(.cancel)
        completionHandler = nil
    }

    // MARK: - Internal state (public for cross-module access from SwiftUI)

    public var completionHandler: (@MainActor (Response) -> Void)?
    public var panelState = PanelState()

    /// The currently active panel (one at a time). The App render loop checks this.
    nonisolated(unsafe) public static var _activePanel: NSSavePanel?

    /// Resolve with a selected file path.
    @MainActor public func resolve(path: String) {
        url = URL(fileURLWithPath: path)
        isVisible = false
        NSSavePanel._activePanel = nil
        completionHandler?(.OK)
        completionHandler = nil
    }
}

// MARK: - NSOpenPanel

/// A panel that lets the user choose files or directories to open.
/// On Clone, this renders as a SwiftUI overlay inside the app's window.
open class NSOpenPanel: NSSavePanel {
    /// Whether the user can select directories.
    public var canChooseDirectories: Bool = false
    /// Whether the user can select files.
    public var canChooseFiles: Bool = true
    /// Whether multiple selection is allowed.
    public var allowsMultipleSelection: Bool = false
}

// MARK: - Panel state (internal, drives the file browser UI)

public final class PanelState {
    public var currentPath: String = ""
    public var entries: [PanelEntry] = []
    public var selectedIndex: Int = 0
    public var mouseX: CGFloat = 0
    public var mouseY: CGFloat = 0

    public struct PanelEntry {
        public let name: String
        public let isDirectory: Bool
        public let path: String
    }

    public func loadDirectory() {
        let fm = FileManager.default
        var result: [PanelEntry] = []
        if currentPath != "/" {
            result.append(PanelEntry(name: "..", isDirectory: true, path: (currentPath as NSString).deletingLastPathComponent))
        }
        if let contents = try? fm.contentsOfDirectory(atPath: currentPath) {
            for name in contents.sorted() where !name.hasPrefix(".") {
                let fullPath = (currentPath as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                fm.fileExists(atPath: fullPath, isDirectory: &isDir)
                result.append(PanelEntry(name: name, isDirectory: isDir.boolValue, path: fullPath))
            }
        }
        entries = result
        selectedIndex = min(selectedIndex, max(entries.count - 1, 0))
    }
}
