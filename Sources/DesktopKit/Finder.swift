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
        ZStack {
            // Window background
            RoundedRectangle(cornerRadius: 12)
                .fill(.surface)
                .frame(width: width, height: height)
            VStack(alignment: .leading, spacing: 0) {
                titleBar()
                pathBar()
                fileList()
            }
        }
    }

    private func titleBar() -> ViewNode {
        ZStack {
            RoundedRectangle(cornerRadius: 0)
                .fill(.overlay)
                .frame(width: width, height: 38)
            HStack(spacing: 8) {
                // Traffic light buttons
                RoundedRectangle(cornerRadius: 6).fill(.systemRed).frame(width: 12, height: 12)
                RoundedRectangle(cornerRadius: 6).fill(.systemYellow).frame(width: 12, height: 12)
                RoundedRectangle(cornerRadius: 6).fill(.systemGreen).frame(width: 12, height: 12)
                Spacer()
                Text("Finder").fontSize(13).foregroundColor(.text)
                Spacer()
            }
        }
        .frame(width: width, height: 38)
    }

    private func pathBar() -> ViewNode {
        Text(currentPath)
            .fontSize(12)
            .foregroundColor(.subtle)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
    }

    private func fileList() -> ViewNode {
        let rows: [ViewNode] = entries.map { entry in fileRow(entry) }
        return ViewNode.vstack(alignment: .leading, spacing: 1, children: rows)
    }

    private func fileRow(_ entry: FileEntry) -> ViewNode {
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
    }
}
