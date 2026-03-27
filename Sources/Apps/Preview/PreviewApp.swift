import Foundation
import SwiftUI
#if canImport(CloneProtocol)
import CloneProtocol
#endif

// MARK: - Colors

#if canImport(AppKit) && !canImport(CloneClient)
import AppKit
var previewBg: Color { Color(nsColor: .windowBackgroundColor) }
var toolbarBg: Color { Color(nsColor: .controlBackgroundColor) }
var toolbarBorder: Color { Color(nsColor: .separatorColor) }
#else
let previewBg = Color(red: 0.18, green: 0.18, blue: 0.18)
let toolbarBg = Color(red: 0.95, green: 0.95, blue: 0.96)
let toolbarBorder = Color(red: 0, green: 0, blue: 0, opacity: 0.1)
#endif

// MARK: - File types

enum PreviewFileType {
    case image, text, unknown
}

func detectFileType(_ path: String) -> PreviewFileType {
    let lower = path.lowercased()
    if lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg")
        || lower.hasSuffix(".gif") || lower.hasSuffix(".bmp") || lower.hasSuffix(".webp") { return .image }
    if lower.hasSuffix(".txt") || lower.hasSuffix(".swift") || lower.hasSuffix(".rs")
        || lower.hasSuffix(".json") || lower.hasSuffix(".md") || lower.hasSuffix(".toml")
        || lower.hasSuffix(".yaml") || lower.hasSuffix(".yml") || lower.hasSuffix(".sh")
        || lower.hasSuffix(".py") || lower.hasSuffix(".go") || lower.hasSuffix(".c")
        || lower.hasSuffix(".h") { return .text }
    return .unknown
}

// MARK: - State

final class PreviewState {
    var filePath: String = ""
    var fileName: String = "No File"
    var fileType: PreviewFileType = .unknown
    var textContent: String = ""
    var textLines: [String] = []
    var scale: CGFloat = 1.0
    var mouseX: CGFloat = 0
    var mouseY: CGFloat = 0
    var showingOpenPanel: Bool = false

    let toolbarHeight: CGFloat = 40
    let lineHeight: CGFloat = 18

    func loadFile(_ path: String) {
        filePath = path
        fileName = (path as NSString).lastPathComponent
        fileType = detectFileType(path)

        if fileType == .text {
            textContent = (try? String(contentsOfFile: path, encoding: .utf8)) ?? "Unable to read file"
        } else {
            textContent = ""
        }
        textLines = textContent.components(separatedBy: "\n")
    }

    func loadSample() {
        fileName = "sample.txt"
        fileType = .text
        textContent = "# Preview\n\nThis is a sample file.\nOpen a real file by passing its path as an argument:\n\n  swift run PreviewApp /path/to/file.txt\n\nSupported formats:\n  - Text files (.txt, .swift, .rs, .json, .md, .py, .go)\n  - Images (.png, .jpg) — pending engine texture support"
        textLines = textContent.components(separatedBy: "\n")
    }

    func zoomIn() { scale = min(scale * 1.25, 5.0) }
    func zoomOut() { scale = max(scale / 1.25, 0.25) }
    func zoomFit() { scale = 1.0 }
}

// MARK: - Text line row

@MainActor private func previewTextLine(line: String, fontSize: CGFloat, lineHeight: CGFloat) -> some View {
    Text(line.isEmpty ? " " : line)
        .font(.system(size: fontSize))
        .foregroundColor(.primary)
        .frame(height: lineHeight)
}

// MARK: - Root view

@MainActor func previewView(state: PreviewState, width: CGFloat, height: CGFloat) -> some View {
    let contentHeight = height - state.toolbarHeight - 1
    let fontSize = 13 * state.scale
    let scaledLineHeight = state.lineHeight * state.scale

    // Toolbar
    let toolbar = HStack(spacing: 12) {
        Text(state.fileName)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.primary)
        Spacer()
        Text("\u{2212}")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.secondary)
            .frame(width: 24, height: 24)
        Text("\(Int(state.scale * 100))%")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .frame(width: 44)
        Text("+")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.secondary)
            .frame(width: 24, height: 24)
    }
    .padding(.horizontal, 16)

    // Content
    let textContent = VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(state.textLines.enumerated()), id: \.offset) { _, line in
            previewTextLine(line: line, fontSize: fontSize, lineHeight: scaledLineHeight)
        }
        Spacer()
    }
    .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

    let imageContent: Image? = state.fileType == .image && !state.filePath.isEmpty
        ? Image(contentsOfFile: state.filePath) : nil

    let placeholder = VStack(spacing: 8) {
        Spacer()
        Text("No file loaded")
            .font(.system(size: 14))
            .foregroundColor(.secondary)
        Text(state.fileName)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
        Spacer()
    }

    let showText = state.fileType == .text
    let showImage = state.fileType == .image && imageContent != nil
    let contentBg: Color = showText ? Color(red: 1.0, green: 1.0, blue: 1.0) : previewBg

    return VStack(spacing: 0) {
        // Toolbar
        ZStack {
            Rectangle().fill(toolbarBg).frame(width: width, height: state.toolbarHeight)
            toolbar
        }.frame(width: width, height: state.toolbarHeight)

        // Separator
        Rectangle().fill(toolbarBorder).frame(width: width, height: 1)

        // Content area
        ZStack {
            Rectangle().fill(contentBg).frame(width: width, height: contentHeight)
            if showText {
                textContent
            } else if showImage, let img = imageContent {
                img.resizable()
            } else {
                placeholder
            }
        }.frame(width: width, height: contentHeight)
    }
}

// MARK: - Keycodes

private let kKeyEquals: UInt32 = 46
private let kKeyMinus: UInt32 = 45
private let kKeyZero: UInt32 = 39

// MARK: - App

@main
struct PreviewApp: App {
    let state = PreviewState()

    var body: some Scene {
        WindowGroup("Preview") {
            GeometryReader { proxy in
                previewView(state: state, width: proxy.size.width, height: proxy.size.height)
            }
            .fileImporter(
                isPresented: Binding(get: { state.showingOpenPanel }, set: { state.showingOpenPanel = $0 }),
                allowedContentTypes: [.image, .pdf]
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    state.loadFile(url.path)
                }
            }
        }
        .commands {
            CommandMenu("File") {
                Button("Open…") { state.showingOpenPanel = true }
            }
        }
    }

    init() {
        let args = CommandLine.arguments
        if args.count > 1 {
            state.loadFile(args[1])
        } else {
            state.loadSample()
        }
    }

    #if canImport(CloneClient)
    var configuration: WindowConfiguration {
        WindowConfiguration(title: "Preview — \(state.fileName)", width: 700, height: 500, role: .window)
    }

    // Register menus on first frame
    private static var menusRegistered = false

    func onOpenFile(path: String) {
        state.loadFile(path)
        client.send(.setTitle(title: "Preview — \(state.fileName)"))
    }

    func onPointerMove(x: CGFloat, y: CGFloat) {
        state.mouseX = x
        state.mouseY = y
    }

    func onPointerButton(button: UInt32, pressed: Bool, x: CGFloat, y: CGFloat) {
        guard button == 0 && pressed else { return }
        if y < state.toolbarHeight {
            let zoomMinusX = WindowState.shared.width - 120
            let zoomPlusX = WindowState.shared.width - 48
            if x >= zoomMinusX && x < zoomMinusX + 24 { state.zoomOut() }
            else if x >= zoomPlusX && x < zoomPlusX + 24 { state.zoomIn() }
        }
    }

    func onKey(keycode: UInt32, pressed: Bool) {
        guard pressed else { return }

        // Register menus on first interaction (lazy — avoids race with connection)
        if !PreviewApp.menusRegistered {
            client.send(.registerMenus(menus: [
                AppMenu(title: "File", items: [
                    AppMenuItem(id: "file.open", title: "Open...", shortcut: "⌘O"),
                    AppMenuItem.separator(),
                    AppMenuItem(id: "file.close", title: "Close Window", shortcut: "⌘W"),
                ]),
                AppMenu(title: "View", items: [
                    AppMenuItem(id: "view.zoomin", title: "Zoom In", shortcut: "⌘+"),
                    AppMenuItem(id: "view.zoomout", title: "Zoom Out", shortcut: "⌘-"),
                    AppMenuItem(id: "view.actual", title: "Actual Size", shortcut: "⌘0"),
                ]),
            ]))
            PreviewApp.menusRegistered = true
        }

        switch keycode {
        case kKeyEquals: state.zoomIn()
        case kKeyMinus: state.zoomOut()
        case kKeyZero: state.zoomFit()
        default: break
        }
    }

    func onMenuAction(itemId: String) {
        switch itemId {
        case "file.open":
            let panel = NSOpenPanel()
            panel.allowedContentTypes = ["txt", "swift", "rs", "json", "md", "png", "jpg", "jpeg"]
            panel.begin { [state, client] response in
                if response == .OK, let url = panel.url {
                    state.loadFile(url.path)
                    client.send(.setTitle(title: "Preview — \(state.fileName)"))
                }
            }
        case "view.zoomin": state.zoomIn()
        case "view.zoomout": state.zoomOut()
        case "view.actual": state.zoomFit()
        case "file.close": client.send(.close)
        default: break
        }
    }
    #endif
}
