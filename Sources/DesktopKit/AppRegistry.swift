import Foundation

/// An app that can be launched into a window.
public protocol App {
    var appId: String { get }
    var defaultTitle: String { get }
    var defaultWidth: Float { get }
    var defaultHeight: Float { get }

    /// Build the app's content view for a given window size.
    func body(width: Float, height: Float) -> ViewNode
}

/// Registry of available apps. Launch them to create windows.
public final class AppRegistry {
    public static let shared = AppRegistry()

    private var apps: [String: App] = [:]

    private init() {}

    public func register(_ app: App) {
        apps[app.appId] = app
    }

    public func get(_ appId: String) -> App? {
        apps[appId]
    }

    public var allApps: [App] {
        Array(apps.values)
    }

    /// Launch an app as a new window in the WindowManager.
    @discardableResult
    public func launch(_ appId: String, windowManager: WindowManager, x: Float, y: Float) -> UInt64? {
        guard let app = apps[appId] else { return nil }
        return windowManager.open(
            appId: appId,
            title: app.defaultTitle,
            x: x, y: y,
            width: app.defaultWidth,
            height: app.defaultHeight
        )
    }
}

// MARK: - Built-in apps

/// Finder app — file browser
public struct FinderApp: App {
    public let appId = "com.clone.finder"
    public let defaultTitle = "Finder"
    public let defaultWidth: Float = 600
    public let defaultHeight: Float = 438 // 400 + title bar

    private let entries: [Finder.FileEntry]

    public init(entries: [Finder.FileEntry] = FinderApp.defaultEntries) {
        self.entries = entries
    }

    public func body(width: Float, height: Float) -> ViewNode {
        let contentHeight = height - WindowChrome.titleBarHeight
        let finder = Finder(
            width: width,
            height: contentHeight,
            currentPath: "/Users/manz",
            entries: entries
        )
        // Return just the content — window chrome is added by WindowManager
        return finderContent(width: width, height: contentHeight)
    }

    private func finderContent(width: Float, height: Float) -> ViewNode {
        VStack(alignment: .leading, spacing: 0) {
            // Path bar
            Text("/Users/manz")
                .fontSize(12)
                .foregroundColor(.subtle)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            // File list
            ViewNode.vstack(alignment: .leading, spacing: 1, children: entries.map { entry in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(entry.isDirectory ? .systemBlue : .muted)
                        .frame(width: 20, height: 20)
                    Text(entry.name).fontSize(13).foregroundColor(.text)
                    Spacer()
                    Text(entry.displaySize).fontSize(11).foregroundColor(.subtle)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            })
            Spacer()
        }
    }

    public static let defaultEntries: [Finder.FileEntry] = [
        Finder.FileEntry(name: "Applications", isDirectory: true),
        Finder.FileEntry(name: "Documents", isDirectory: true),
        Finder.FileEntry(name: "Downloads", isDirectory: true),
        Finder.FileEntry(name: "Desktop", isDirectory: true),
        Finder.FileEntry(name: "Music", isDirectory: true),
        Finder.FileEntry(name: "Pictures", isDirectory: true),
        Finder.FileEntry(name: "readme.txt", isDirectory: false, size: 1234),
        Finder.FileEntry(name: "notes.md", isDirectory: false, size: 5678),
        Finder.FileEntry(name: "photo.jpg", isDirectory: false, size: 2_500_000),
    ]
}

/// Terminal app — placeholder
public struct TerminalApp: App {
    public let appId = "com.clone.terminal"
    public let defaultTitle = "Terminal"
    public let defaultWidth: Float = 560
    public let defaultHeight: Float = 378

    public init() {}

    public func body(width: Float, height: Float) -> ViewNode {
        let contentHeight = height - WindowChrome.titleBarHeight
        return ZStack {
            Rectangle()
                .fill(DesktopColor(r: 0.08, g: 0.07, b: 0.11))
                .frame(width: width, height: contentHeight)
            VStack(alignment: .leading, spacing: 4) {
                Text("manz@clone ~ %")
                    .fontSize(13)
                    .foregroundColor(.systemGreen)
                Spacer()
            }
            .padding(12)
        }
    }
}

/// Settings app — placeholder
public struct SettingsApp: App {
    public let appId = "com.clone.settings"
    public let defaultTitle = "System Settings"
    public let defaultWidth: Float = 500
    public let defaultHeight: Float = 400

    public init() {}

    public func body(width: Float, height: Float) -> ViewNode {
        let contentHeight = height - WindowChrome.titleBarHeight
        return VStack(alignment: .leading, spacing: 12) {
            Text("System Settings")
                .fontSize(20)
                .bold()
                .foregroundColor(.text)
            HStack(spacing: 12) {
                settingsItem("General", color: .muted)
                settingsItem("Appearance", color: .systemBlue)
                settingsItem("Desktop", color: .systemGreen)
            }
            HStack(spacing: 12) {
                settingsItem("Dock", color: .systemOrange)
                settingsItem("Display", color: .systemBlue)
                settingsItem("Sound", color: .systemRed)
            }
            Spacer()
        }
        .padding(20)
    }

    private func settingsItem(_ name: String, color: DesktopColor) -> ViewNode {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 12)
                .fill(color)
                .frame(width: 56, height: 56)
            Text(name).fontSize(11).foregroundColor(.text)
        }
    }
}
