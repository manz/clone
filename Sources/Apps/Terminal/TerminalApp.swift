import Foundation
import SwiftUI
#if canImport(CloneClient)
import CloneClient
#endif
import CloneTerminalVT

private let kWinW: CGFloat = 800
private let kWinH: CGFloat = 500
private let kFontSize: CGFloat = 14

// MARK: - State

// @unchecked Sendable: onUpdate fires on the pty reader thread; mutations hop to
// main via DispatchQueue.main.async.
final class TerminalState: @unchecked Sendable {
    let session: TerminalSession?
    var cells: [[TermCell]] = []
    var cursorCol: Int = 0
    var cursorRow: Int = 0
    var cursorVisible: Bool = true
    let cellW: CGFloat
    let cellH: CGFloat

    init(width: CGFloat, height: CGFloat) {
        // Measure the monospace cell so cols/rows fit the window and the cursor
        // lands on the right cell.
        let cell = TextMeasurer.measure("M", fontSize: kFontSize, weight: .regular, family: "Iosevka")
        cellW = cell.width > 1 ? cell.width : 8.4
        cellH = cell.height > 1 ? cell.height : 18
        let cols = UInt16(max(20, min(400, Int(width / cellW))))
        let rows = UInt16(max(5, min(200, Int(height / cellH))))

        let s = TerminalSession(cols: cols, rows: rows)
        session = s
        s?.onUpdate = { [weak self] in
            guard let self, let s = self.session else { return }
            let grid = s.screenCells()
            let cur = s.cursor
            let vis = s.cursorVisible
            DispatchQueue.main.async {
                self.cells = grid
                self.cursorCol = cur.col
                self.cursorRow = cur.row
                self.cursorVisible = vis
                requestRedraw()
            }
        }
        // NixOS has no /bin/bash, so use the login shell, fall back to /bin/sh.
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/sh"
        s?.start(shell: shell)
    }
}

// MARK: - View

// Terminal default fg/bg, used when a cell carries no explicit color.
private let kDefaultFg = TermColor(r: 217, g: 222, b: 230)
private let kDefaultBg = TermColor(r: 13, g: 13, b: 15)

private func swiftColor(_ c: TermColor) -> Color {
    Color(red: Double(c.r) / 255, green: Double(c.g) / 255, blue: Double(c.b) / 255, opacity: 1)
}

// A run of consecutive same-styled cells, drawn as one Text (keeps the view count
// down vs one Text per cell).
private struct RenderRun { var text: String; var cells: Int; var fg: TermColor; var bg: TermColor?; var bold: Bool }

// `cursorCol` (when set) marks the cell to draw as the block cursor. Clone's
// SwiftUI has no .offset, so the cursor is a cell attribute, the way real
// terminals render it.
private func mergeRuns(_ row: [TermCell], cursorCol: Int?) -> [RenderRun] {
    var runs: [RenderRun] = []
    for (i, c) in row.enumerated() {
        var fg = c.fg ?? kDefaultFg
        var bg = c.bg
        if c.inverse {            // swap fg/bg, filling in defaults
            let newFg = bg ?? kDefaultBg
            bg = c.fg ?? kDefaultFg
            fg = newFg
        }
        if i == cursorCol {       // block cursor: light block under a dark glyph
            fg = kDefaultBg
            bg = TermColor(r: 217, g: 222, b: 230)
        }
        if !runs.isEmpty, runs[runs.count - 1].fg == fg, runs[runs.count - 1].bg == bg,
           runs[runs.count - 1].bold == c.bold {
            runs[runs.count - 1].text += c.text
            runs[runs.count - 1].cells += 1
        } else {
            runs.append(RenderRun(text: c.text, cells: 1, fg: fg, bg: bg, bold: c.bold))
        }
    }
    return runs
}

@MainActor func terminalRow(_ row: [TermCell], cellW: CGFloat, cellH: CGFloat, cursorCol: Int?) -> some View {
    let runs = mergeRuns(row, cursorCol: cursorCol)
    let clear = Color(red: 0, green: 0, blue: 0, opacity: 0)
    return HStack(alignment: .top, spacing: 0) {
        ForEach(Array(runs.enumerated()), id: \.offset) { _, run in
            Text(run.text)
                .font(.system(size: kFontSize, design: .monospaced))
                .fontWeight(run.bold ? .bold : .regular)
                .foregroundColor(swiftColor(run.fg))
                .frame(width: CGFloat(run.cells) * cellW, height: cellH, alignment: .leading)
                .background(run.bg.map(swiftColor) ?? clear)
        }
    }
    .frame(height: cellH)
}

@MainActor func terminalView(state: TerminalState, width: CGFloat, height: CGFloat) -> some View {
    return ZStack(alignment: .topLeading) {
        Rectangle()
            .fill(swiftColor(kDefaultBg))
            .frame(width: width, height: height)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(state.cells.enumerated()), id: \.offset) { idx, row in
                terminalRow(row, cellW: state.cellW, cellH: state.cellH,
                            cursorCol: (state.cursorVisible && idx == state.cursorRow) ? state.cursorCol : nil)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }
    .frame(width: width, height: height)
}

// MARK: - App

@main
struct TerminalApp: App {
    let state = TerminalState(width: kWinW, height: kWinH)

    var body: some Scene {
        WindowGroup("Terminal") {
            terminalView(state: state, width: kWinW, height: kWinH)
        }
    }

    #if canImport(CloneClient)
    var configuration: WindowConfiguration {
        WindowConfiguration(title: "Terminal", width: kWinW, height: kWinH, role: .window)
    }

    func onKeyChar(character: String) {
        state.session?.send(character)
    }

    func onKey(keycode: UInt32, modifiers: UInt32, pressed: Bool) {
        guard pressed else { return }
        let esc: String?
        switch keycode {
        case 103: esc = "\u{1b}[A"   // up
        case 108: esc = "\u{1b}[B"   // down
        case 106: esc = "\u{1b}[C"   // right
        case 105: esc = "\u{1b}[D"   // left
        default: esc = nil
        }
        if let esc { state.session?.send(esc) }
    }

    // Mouse/trackpad scroll → VT scrollback (3-line step; negative = up).
    func onScroll(deltaX: CGFloat, deltaY: CGFloat) {
        guard abs(deltaY) > 0.1 else { return }
        state.session?.scroll(lines: deltaY > 0 ? 3 : -3)
    }
    #endif
}
