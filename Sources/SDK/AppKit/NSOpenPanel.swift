import Foundation

// MARK: - NSSavePanel

/// Base panel for file save/open dialogs. On Clone, panels render as a sheet
/// using the shared FileBrowserState and FileListView from the SwiftUI SDK.
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
        startPath = directoryURL?.path ?? NSHomeDirectory()
        NSSavePanel._activePanel = self
    }

    /// Cancel the panel programmatically.
    @MainActor public func cancel() {
        isVisible = false
        NSSavePanel._activePanel = nil
        completionHandler?(.cancel)
        completionHandler = nil
    }

    // MARK: - Internal

    public var completionHandler: (@MainActor (Response) -> Void)?

    /// Starting path resolved at begin() time.
    public var startPath: String = NSHomeDirectory()

    /// The currently active panel (one at a time).
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
open class NSOpenPanel: NSSavePanel {
    public var canChooseDirectories: Bool = false
    public var canChooseFiles: Bool = true
    public var allowsMultipleSelection: Bool = false
}
