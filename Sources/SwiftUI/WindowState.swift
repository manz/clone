import Foundation

/// Shared state for the current window, updated by the App runtime each frame.
/// Views read this for window dimensions; `.navigationTitle()` writes to it.
public final class WindowState: @unchecked Sendable {
    public static let shared = WindowState()

    /// Current window dimensions (updated by App.main on each frame request).
    public private(set) var width: CGFloat = 0
    public private(set) var height: CGFloat = 0

    /// The current navigation title. Set by `.navigationTitle()`, read by the runtime.
    public var navigationTitle: String?

    /// Toolbar items collected during view tree build. Reset each frame.
    public var toolbarItems: [ToolbarItemData] = []
    /// Source keys already seen this frame — prevents duplicates from multi-path evaluation.
    private var toolbarSourceKeys: Set<String> = []

    /// Add toolbar items, skipping duplicates from the same source location.
    public func addToolbarItems(_ items: [ToolbarItemData], sourceKey: String) {
        guard toolbarSourceKeys.insert(sourceKey).inserted else { return }
        toolbarItems.append(contentsOf: items)
    }

    /// The title from the previous frame — used to detect changes.
    internal var previousTitle: String?

    private init() {}

    /// Called by App.main() at the start of each frame.
    internal func update(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
        self.navigationTitle = nil // Reset — views will set it during tree build
        self.toolbarItems = []
        self.toolbarSourceKeys = []
    }

    /// Returns true if the title changed since last frame.
    internal func titleDidChange() -> Bool {
        let changed = navigationTitle != previousTitle
        previousTitle = navigationTitle
        return changed
    }
}

/// Data for a toolbar item collected during view tree build.
public struct ToolbarItemData {
    public let placement: ToolbarItemPlacement
    public let node: ViewNode
    public let sourceKey: String  // file:line to deduplicate
}

// MARK: - System Actions

/// Action to launch an app by its bundle ID.
public struct LaunchAppAction {
    private let handler: (String) -> Void

    public init(_ handler: @escaping (String) -> Void) {
        self.handler = handler
    }

    public func callAsFunction(_ appId: String) {
        handler(appId)
    }
}

/// Action to restore a minimized app by its bundle ID.
public struct RestoreAppAction {
    private let handler: (String) -> Void

    public init(_ handler: @escaping (String) -> Void) {
        self.handler = handler
    }

    public func callAsFunction(_ appId: String) {
        handler(appId)
    }
}

/// Action to signal the compositor that authentication succeeded.
public struct SessionReadyAction {
    private let handler: () -> Void

    public init(_ handler: @escaping () -> Void) {
        self.handler = handler
    }

    public func callAsFunction() {
        handler()
    }
}

/// Global system actions — wired up by App.main().
public final class SystemActions: @unchecked Sendable {
    public static let shared = SystemActions()

    public var launchApp = LaunchAppAction { _ in }
    public var restoreApp = RestoreAppAction { _ in }
    public var sessionReady = SessionReadyAction {}

    private init() {}
}
