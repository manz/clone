import Foundation
import SwiftUI
#if canImport(CloneProtocol)
import CloneProtocol
#endif

// MARK: - Colors

#if canImport(AppKit) && !canImport(CloneClient)
import AppKit
var editorBg: Color { Color(nsColor: .textBackgroundColor) }
var gutterBg: Color { Color(nsColor: .controlBackgroundColor) }
var gutterText: Color { Color(nsColor: .secondaryLabelColor) }
var cursorColor: Color { Color(nsColor: .textColor) }
var statusBg: Color { Color(nsColor: .controlBackgroundColor) }
var statusBorder: Color { Color(nsColor: .separatorColor) }
#else
let editorBg = Color(red: 1.0, green: 1.0, blue: 1.0)
let gutterBg = Color(red: 0.96, green: 0.96, blue: 0.97)
let gutterText = Color(red: 0.6, green: 0.6, blue: 0.6)
let cursorColor = Color(red: 0.0, green: 0.0, blue: 0.0)
let statusBg = Color(red: 0.95, green: 0.95, blue: 0.96)
let statusBorder = Color(red: 0, green: 0, blue: 0, opacity: 0.1)
#endif

// MARK: - State

final class TextEditorState {
    var text: String = "Welcome to TextEdit.\n\nStart typing to edit this document.\nUse arrow keys to navigate.\n\nLine 6\nLine 7\nLine 8"
    var cursorLine: Int = 0
    var cursorCol: Int = 0
    var fontSize: CGFloat = 14
    var mouseX: CGFloat = 0
    var mouseY: CGFloat = 0

    let gutterWidth: CGFloat = 44
    let statusHeight: CGFloat = 24
    let lineHeight: CGFloat = 20
    let charWidth: CGFloat = 8.4

    var lines: [String] { text.components(separatedBy: "\n") }
    var lineCount: Int { lines.count }

    func insertCharacter(_ char: String) {
        var ls = lines
        guard cursorLine < ls.count else { return }
        var line = ls[cursorLine]
        let idx = line.index(line.startIndex, offsetBy: min(cursorCol, line.count))
        line.insert(contentsOf: char, at: idx)
        ls[cursorLine] = line
        text = ls.joined(separator: "\n")
        cursorCol += char.count
    }

    func insertNewline() {
        var ls = lines
        guard cursorLine < ls.count else { return }
        let line = ls[cursorLine]
        let idx = line.index(line.startIndex, offsetBy: min(cursorCol, line.count))
        ls[cursorLine] = String(line[line.startIndex..<idx])
        ls.insert(String(line[idx...]), at: cursorLine + 1)
        text = ls.joined(separator: "\n")
        cursorLine += 1
        cursorCol = 0
    }

    func deleteBackward() {
        var ls = lines
        guard cursorLine < ls.count else { return }
        if cursorCol > 0 {
            var line = ls[cursorLine]
            let idx = line.index(line.startIndex, offsetBy: cursorCol)
            line.remove(at: line.index(before: idx))
            ls[cursorLine] = line
            text = ls.joined(separator: "\n")
            cursorCol -= 1
        } else if cursorLine > 0 {
            let prev = ls[cursorLine - 1]
            ls[cursorLine - 1] = prev + ls[cursorLine]
            ls.remove(at: cursorLine)
            text = ls.joined(separator: "\n")
            cursorLine -= 1
            cursorCol = prev.count
        }
    }

    func moveUp() { if cursorLine > 0 { cursorLine -= 1; cursorCol = min(cursorCol, lines[cursorLine].count) } }
    func moveDown() { if cursorLine < lines.count - 1 { cursorLine += 1; cursorCol = min(cursorCol, lines[cursorLine].count) } }
    func moveLeft() { if cursorCol > 0 { cursorCol -= 1 } else if cursorLine > 0 { cursorLine -= 1; cursorCol = lines[cursorLine].count } }
    func moveRight() {
        let len = cursorLine < lines.count ? lines[cursorLine].count : 0
        if cursorCol < len { cursorCol += 1 } else if cursorLine < lines.count - 1 { cursorLine += 1; cursorCol = 0 }
    }
}

// MARK: - Keycodes (winit physical key codes)

private let kKeyUp: UInt32 = 82
private let kKeyDown: UInt32 = 81
private let kKeyLeft: UInt32 = 80
private let kKeyRight: UInt32 = 79
private let kKeyBackspace: UInt32 = 42
private let kKeyEnter: UInt32 = 40

// MARK: - Line number row

@MainActor private func lineNumberRow(number: Int, state: TextEditorState) -> some View {
    Text("\(number)")
        .font(.system(size: 12))
        .foregroundColor(gutterText)
        .frame(width: state.gutterWidth - 8, height: state.lineHeight)
}

// MARK: - Text line row

@MainActor private func textLineRow(line: String, state: TextEditorState) -> some View {
    Text(line.isEmpty ? " " : line)
        .font(.system(size: state.fontSize))
        .foregroundColor(.primary)
        .frame(height: state.lineHeight)
}

// MARK: - Root view

@MainActor func textEditView(state: TextEditorState, width: CGFloat, height: CGFloat) -> some View {
    let editorHeight = height - state.statusHeight - 1
    let textAreaWidth = width - state.gutterWidth
    let totalLines = state.lines
    let cursorX = 8 + CGFloat(state.cursorCol) * state.charWidth
    let cursorY = 4 + CGFloat(state.cursorLine) * state.lineHeight

    let gutter = VStack(alignment: .trailing, spacing: 0) {
        ForEach(Array(totalLines.enumerated()), id: \.offset) { i, _ in
            lineNumberRow(number: i + 1, state: state)
        }
        Spacer()
    }
    .padding(EdgeInsets(top: 4, leading: 0, bottom: 0, trailing: 4))

    let textArea = VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(totalLines.enumerated()), id: \.offset) { i, line in
            textLineRow(line: line, state: state)
        }
        Spacer()
    }
    .padding(EdgeInsets(top: 4, leading: 8, bottom: 0, trailing: 8))

    let cursor = Rectangle()
        .foregroundColor(cursorColor)
        .frame(width: 2, height: state.lineHeight)

    let statusBar = HStack(spacing: 16) {
        Text("Ln \(state.cursorLine + 1), Col \(state.cursorCol + 1)")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        Spacer()
        Text("\(state.lineCount) lines")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        Text("UTF-8")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
    }
    .padding(.horizontal, 12)

    return VStack(spacing: 0) {
        HStack(alignment: .top, spacing: 0) {
            ZStack {
                Rectangle().fill(gutterBg).frame(width: state.gutterWidth, height: editorHeight)
                gutter
            }.frame(width: state.gutterWidth, height: editorHeight)

            ZStack(alignment: .topLeading) {
                Rectangle().fill(editorBg).frame(width: textAreaWidth, height: editorHeight)
                textArea
                cursor.padding(EdgeInsets(top: cursorY, leading: cursorX, bottom: 0, trailing: 0))
            }.frame(width: textAreaWidth, height: editorHeight)
        }

        Rectangle().fill(statusBorder).frame(width: width, height: 1)

        ZStack {
            Rectangle().fill(statusBg).frame(width: width, height: state.statusHeight)
            statusBar
        }.frame(width: width, height: state.statusHeight)
    }
}

// MARK: - App

@main
struct TextEditApp: App {
    let state = TextEditorState()

    var body: some Scene {
        WindowGroup("TextEdit") {
            #if canImport(AppKit) && !canImport(CloneClient)
            GeometryReader { proxy in
                textEditView(state: state, width: proxy.size.width, height: proxy.size.height)
            }
            #else
            textEditView(state: state, width: WindowState.shared.width, height: WindowState.shared.height)
            #endif
        }
    }

    #if canImport(CloneClient)
    var configuration: WindowConfiguration {
        WindowConfiguration(title: "TextEdit", width: 700, height: 500, role: .window)
    }

    func onPointerMove(x: CGFloat, y: CGFloat) {
        state.mouseX = x
        state.mouseY = y
    }

    func onPointerButton(button: UInt32, pressed: Bool, x: CGFloat, y: CGFloat) {
        guard button == 0 && pressed else { return }
        if x > state.gutterWidth {
            let textX = x - state.gutterWidth - 8
            let textY = y - 4
            let line = max(0, min(Int(textY / state.lineHeight), state.lines.count - 1))
            let col = max(0, min(Int(textX / state.charWidth), state.lines[line].count))
            state.cursorLine = line
            state.cursorCol = col
        }
    }

    func onKey(keycode: UInt32, pressed: Bool) {
        guard pressed else { return }
        switch keycode {
        case kKeyUp: state.moveUp()
        case kKeyDown: state.moveDown()
        case kKeyLeft: state.moveLeft()
        case kKeyRight: state.moveRight()
        case kKeyBackspace: state.deleteBackward()
        case kKeyEnter: state.insertNewline()
        default: break
        }
    }

    func onKeyChar(character: String) {
        registerMenusIfNeeded()
        guard let first = character.unicodeScalars.first,
              first.value >= 0x20 else { return }
        state.insertCharacter(character)
    }

    private static var menusRegistered = false

    private func registerMenusIfNeeded() {
        guard !TextEditApp.menusRegistered else { return }
        client.send(.registerMenus(menus: [
            AppMenu(title: "File", items: [
                AppMenuItem(id: "file.new", title: "New", shortcut: "⌘N"),
                AppMenuItem(id: "file.open", title: "Open...", shortcut: "⌘O"),
                AppMenuItem.separator(),
                AppMenuItem(id: "file.close", title: "Close Window", shortcut: "⌘W"),
            ]),
            AppMenu(title: "Edit", items: [
                AppMenuItem(id: "edit.undo", title: "Undo", shortcut: "⌘Z"),
                AppMenuItem.separator(),
                AppMenuItem(id: "edit.cut", title: "Cut", shortcut: "⌘X"),
                AppMenuItem(id: "edit.copy", title: "Copy", shortcut: "⌘C"),
                AppMenuItem(id: "edit.paste", title: "Paste", shortcut: "⌘V"),
                AppMenuItem(id: "edit.selectall", title: "Select All", shortcut: "⌘A"),
            ]),
        ]))
        TextEditApp.menusRegistered = true
    }

    func onMenuAction(itemId: String) {
        switch itemId {
        case "file.open":
            let panel = NSOpenPanel()
            panel.allowedContentTypes = ["txt", "swift", "rs", "json", "md", "py", "go", "c", "h", "toml", "yaml"]
            panel.begin { [state, client] response in
                if response == .OK, let url = panel.url {
                    let content = (try? String(contentsOfFile: url.path, encoding: .utf8)) ?? "Unable to read file"
                    state.text = content
                    state.cursorLine = 0
                    state.cursorCol = 0
                    client.send(.setTitle(title: "TextEdit — \(url.lastPathComponent)"))
                }
            }
        case "file.new":
            state.text = ""
            state.cursorLine = 0
            state.cursorCol = 0
            client.send(.setTitle(title: "TextEdit — Untitled"))
        case "file.close":
            client.send(.close)
        default: break
        }
    }
    #endif
}
