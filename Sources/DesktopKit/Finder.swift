import Foundation

/// Simple file browser component — displays a file list with icons.
public struct Finder {
    let width: Float
    let height: Float
    let currentPath: String
    let entries: [FileEntry]

    public struct FileEntry: Equatable, Sendable {
        public let name: String
        public let isDirectory: Bool
        public let size: UInt64

        public init(name: String, isDirectory: Bool, size: UInt64 = 0) {
            self.name = name
            self.isDirectory = isDirectory
            self.size = size
        }

        public var icon: String {
            isDirectory ? "\u{1F4C1}" : "\u{1F4C4}"
        }

        public var displaySize: String {
            if isDirectory { return "--" }
            if size < 1024 { return "\(size) B" }
            if size < 1024 * 1024 { return "\(size / 1024) KB" }
            return "\(size / (1024 * 1024)) MB"
        }
    }

    public init(width: Float, height: Float, currentPath: String = "/", entries: [FileEntry] = []) {
        self.width = width
        self.height = height
        self.currentPath = currentPath
        self.entries = entries
    }

    public func body() -> ViewNode {
        .zstack(children: [
            // Window background
            ViewNode.roundedRect(width: width, height: height, radius: 12, fill: .surface),
            ViewNode.vstack(alignment: .leading, spacing: 0, children: [
                // Title bar
                titleBar(),
                // Path breadcrumb
                pathBar(),
                // File list
                fileList(),
            ]),
        ])
    }

    private func titleBar() -> ViewNode {
        .zstack(children: [
            ViewNode.roundedRect(width: width, height: 38, radius: 0, fill: .overlay),
            ViewNode.hstack(alignment: .center, spacing: 8, children: [
                // Traffic light buttons
                ViewNode.roundedRect(width: 12, height: 12, radius: 6, fill: .systemRed),
                ViewNode.roundedRect(width: 12, height: 12, radius: 6, fill: .systemYellow),
                ViewNode.roundedRect(width: 12, height: 12, radius: 6, fill: .systemGreen),
                ViewNode.spacer(minLength: 0),
                ViewNode.text("Finder", fontSize: 13, color: .text),
                ViewNode.spacer(minLength: 0),
            ]),
        ])
    }

    private func pathBar() -> ViewNode {
        .padding(
            EdgeInsets(horizontal: 12, vertical: 6),
            child: .text(currentPath, fontSize: 12, color: .subtle)
        )
    }

    private func fileList() -> ViewNode {
        let rows: [ViewNode] = entries.map { entry in
            fileRow(entry)
        }
        return .vstack(alignment: .leading, spacing: 1, children: rows)
    }

    private func fileRow(_ entry: FileEntry) -> ViewNode {
        .padding(
            EdgeInsets(horizontal: 12, vertical: 4),
            child: .hstack(alignment: .center, spacing: 8, children: [
                ViewNode.roundedRect(
                    width: 20, height: 20, radius: 4,
                    fill: entry.isDirectory ? .systemBlue : .muted
                ),
                ViewNode.text(entry.name, fontSize: 13, color: .text),
                ViewNode.spacer(minLength: 0),
                ViewNode.text(entry.displaySize, fontSize: 11, color: .subtle),
            ])
        )
    }
}
