import Foundation
import CloneClient
import CloneProtocol

/// Real Finder app — reads the filesystem, navigates directories.
final class FinderState {
    var currentPath: String
    var entries: [FileEntry] = []
    var mouseX: Float = 0
    var mouseY: Float = 0

    struct FileEntry {
        let name: String
        let isDirectory: Bool
        let size: UInt64
    }

    init(path: String = NSHomeDirectory()) {
        self.currentPath = path
        reload()
    }

    func reload() {
        entries = []
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: currentPath) else { return }

        // Sort: directories first, then alphabetical
        let sorted = items.sorted { a, b in
            var aIsDir: ObjCBool = false
            var bIsDir: ObjCBool = false
            fm.fileExists(atPath: (currentPath as NSString).appendingPathComponent(a), isDirectory: &aIsDir)
            fm.fileExists(atPath: (currentPath as NSString).appendingPathComponent(b), isDirectory: &bIsDir)
            if aIsDir.boolValue != bIsDir.boolValue {
                return aIsDir.boolValue
            }
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }

        for name in sorted {
            // Skip hidden files
            if name.hasPrefix(".") { continue }

            let fullPath = (currentPath as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: fullPath, isDirectory: &isDir)

            var size: UInt64 = 0
            if !isDir.boolValue {
                size = (try? fm.attributesOfItem(atPath: fullPath)[.size] as? UInt64) ?? 0
            }

            entries.append(FileEntry(name: name, isDirectory: isDir.boolValue, size: size))
        }
    }

    func navigate(to name: String) {
        let fullPath = (currentPath as NSString).appendingPathComponent(name)
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir)
        if isDir.boolValue {
            currentPath = fullPath
            reload()
        }
    }

    func goUp() {
        let parent = (currentPath as NSString).deletingLastPathComponent
        if parent != currentPath {
            currentPath = parent
            reload()
        }
    }

    /// Build render commands for the current state.
    func render(width: Float, height: Float) -> [IPCRenderCommand] {
        var commands: [IPCRenderCommand] = []

        // Background
        commands.append(.rect(x: 0, y: 0, w: width, h: height,
                              color: IPCColor(r: 0.18, g: 0.16, b: 0.24, a: 1)))

        // Path bar
        let pathDisplay = shortenPath(currentPath)
        commands.append(.text(x: 12, y: 8, content: pathDisplay, fontSize: 12,
                              color: IPCColor(r: 0.58, g: 0.55, b: 0.63, a: 1),
                              weight: .regular))

        // Back button (if not at root)
        if currentPath != "/" {
            commands.append(.roundedRect(x: width - 60, y: 4, w: 50, h: 20, radius: 4,
                                         color: IPCColor(r: 0.22, g: 0.20, b: 0.28, a: 1)))
            commands.append(.text(x: width - 55, y: 6, content: "< Back", fontSize: 11,
                                  color: IPCColor(r: 0.88, g: 0.85, b: 0.91, a: 1),
                                  weight: .regular))
        }

        // Separator
        commands.append(.rect(x: 0, y: 28, w: width, h: 1,
                              color: IPCColor(r: 0.22, g: 0.20, b: 0.28, a: 1)))

        // File list
        let rowHeight: Float = 28
        let startY: Float = 32
        let maxRows = Int((height - startY) / rowHeight)

        for (i, entry) in entries.prefix(maxRows).enumerated() {
            let y = startY + Float(i) * rowHeight

            // Hover highlight
            let isHovered = mouseY >= y && mouseY < y + rowHeight && mouseX >= 0 && mouseX <= width
            if isHovered {
                commands.append(.rect(x: 0, y: y, w: width, h: rowHeight,
                                      color: IPCColor(r: 0.22, g: 0.20, b: 0.28, a: 0.5)))
            }

            // Icon
            let iconColor = entry.isDirectory
                ? IPCColor(r: 0.19, g: 0.55, b: 0.91, a: 1)
                : IPCColor(r: 0.42, g: 0.39, b: 0.47, a: 1)
            commands.append(.roundedRect(x: 12, y: y + 4, w: 20, h: 20, radius: 4, color: iconColor))

            // Name
            commands.append(.text(x: 40, y: y + 6, content: entry.name, fontSize: 13,
                                  color: IPCColor(r: 0.88, g: 0.85, b: 0.91, a: 1),
                                  weight: .regular))

            // Size
            let sizeText = formatSize(entry)
            commands.append(.text(x: width - 80, y: y + 8, content: sizeText, fontSize: 11,
                                  color: IPCColor(r: 0.58, g: 0.55, b: 0.63, a: 1),
                                  weight: .regular))
        }

        return commands
    }

    /// Handle a click at local coordinates.
    func handleClick(x: Float, y: Float) {
        // Back button
        if currentPath != "/" && x > Float(500 - 60) && y < 28 {
            goUp()
            return
        }

        // File list
        let rowHeight: Float = 28
        let startY: Float = 32
        let rowIndex = Int((y - startY) / rowHeight)
        if rowIndex >= 0 && rowIndex < entries.count {
            let entry = entries[rowIndex]
            if entry.isDirectory {
                navigate(to: entry.name)
            }
        }
    }

    func shortenPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func formatSize(_ entry: FileEntry) -> String {
        if entry.isDirectory { return "--" }
        if entry.size < 1024 { return "\(entry.size) B" }
        if entry.size < 1024 * 1024 { return "\(entry.size / 1024) KB" }
        return "\(entry.size / (1024 * 1024)) MB"
    }
}

// MARK: - Main

let client = AppClient()
let state = FinderState()

do {
    try client.connect(appId: "com.clone.finder", title: "Finder — \(state.currentPath)", width: 600, height: 400)
} catch {
    fputs("Failed to connect to compositor: \(error)\n", stderr)
    exit(1)
}

client.onFrameRequest = { width, height in
    state.render(width: width, height: height)
}

client.onPointerMove = { x, y in
    state.mouseX = x
    state.mouseY = y
}

client.onPointerButton = { button, pressed, x, y in
    if button == 0 && pressed {
        state.handleClick(x: x, y: y)
        client.send(.setTitle(title: "Finder — \(state.shortenPath(state.currentPath))"))
    }
}

client.onKey = { keycode, pressed in
    guard pressed else { return }
    // Backspace (keycode 51 on macOS / 42 winit) — go up
    if keycode == 42 || keycode == 51 {
        state.goUp()
        client.send(.setTitle(title: "Finder — \(state.shortenPath(state.currentPath))"))
    }
}

fputs("Finder connected to compositor\n", stderr)
client.runLoop()
fputs("Finder disconnected\n", stderr)
