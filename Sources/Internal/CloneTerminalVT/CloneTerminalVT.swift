import CGhosttyVt

// Swift bridge over libghostty-vt: VT parsing + terminal/grid state for Terminal.app.
// libghostty-vt does the escape-sequence parsing, scrollback, reflow, etc.; Clone
// owns the PTY (CPty) and the rendering (the grid is drawn with Clone's own Text/Rect).

/// A live terminal instance: feed it PTY output bytes, it maintains the screen state.
public final class GhosttyTerminalVT {
    private var handle: GhosttyTerminal?

    /// Create a `cols`×`rows` terminal with `scrollback` lines of history.
    public init?(cols: UInt16, rows: UInt16, scrollback: Int = 1000) {
        guard ghostty_terminal_new(nil, &handle, cols, rows) == GHOSTTY_SUCCESS, let h = handle else {
            return nil
        }
        var maxLines = scrollback
        _ = ghostty_terminal_set(h, GHOSTTY_TERMINAL_OPT_SCROLLBACK_MAX_LINES, &maxLines)
    }

    deinit {
        if let h = handle { ghostty_terminal_free(h) }
    }

    /// Feed PTY output bytes into the terminal state machine.
    public func write(_ bytes: UnsafeBufferPointer<UInt8>) {
        guard let h = handle, let base = bytes.baseAddress, !bytes.isEmpty else { return }
        ghostty_terminal_vt_write(h, base, bytes.count)
    }

    public func write(_ bytes: [UInt8]) {
        bytes.withUnsafeBufferPointer { write($0) }
    }

    /// Resize the screen. Pixel dims feed pixel-aware sequences (sixel, kitty img).
    public func resize(cols: UInt16, rows: UInt16, cellWidthPx: UInt32 = 0, cellHeightPx: UInt32 = 0) {
        guard let h = handle else { return }
        _ = ghostty_terminal_resize(h, cols, rows, cellWidthPx, cellHeightPx)
    }

    /// Reset the terminal to its initial state.
    public func reset() {
        guard let h = handle else { return }
        ghostty_terminal_reset(h)
    }

    /// Scroll the viewport by `lines` (negative = up into scrollback history,
    /// positive = down toward the bottom/newest).
    public func scrollViewport(lines: Int) {
        guard let h = handle, lines != 0 else { return }
        var b = GhosttyTerminalScrollViewport()
        b.tag = GHOSTTY_TERMINAL_SCROLL_VIEWPORT_DELTA
        b.value.delta = lines
        ghostty_terminal_scroll_viewport(h, b)
    }

    /// Cursor position in the active screen (col, row), 0-indexed.
    public var cursor: (col: Int, row: Int) {
        guard let h = handle else { return (0, 0) }
        var x: UInt16 = 0
        var y: UInt16 = 0
        _ = ghostty_terminal_get(h, GHOSTTY_TERMINAL_DATA_CURSOR_X, &x)
        _ = ghostty_terminal_get(h, GHOSTTY_TERMINAL_DATA_CURSOR_Y, &y)
        return (Int(x), Int(y))
    }

    /// Whether the cursor should be drawn (DEC mode 25). Full-screen apps like
    /// htop hide it and park it at 0,0; honoring this stops a stray block there.
    public var cursorVisible: Bool {
        guard let h = handle else { return true }
        var v = false
        _ = ghostty_terminal_get(h, GHOSTTY_TERMINAL_DATA_CURSOR_VISIBLE, &v)
        return v
    }

    /// The visible screen as plain UTF-8 text (v1 render path, monochrome).
    /// Uses libghostty-vt's formatter (defaults: PLAIN, trimmed). `format_buf`
    /// writes into a reused buffer (no per-frame alloc).
    private var fmtBuf = [UInt8](repeating: 0, count: 64 * 1024)
    public func screenText() -> String {
        guard let h = handle else { return "" }
        var fmt: GhosttyFormatter?
        guard ghostty_formatter_terminal_new(nil, &fmt, h) == GHOSTTY_SUCCESS, let fmt else { return "" }
        defer { ghostty_formatter_free(fmt) }

        var outLen = 0
        let rc = fmtBuf.withUnsafeMutableBufferPointer { buf -> GhosttyResult in
            ghostty_formatter_format_buf(fmt, buf.baseAddress, buf.count, &outLen)
        }
        guard rc == GHOSTTY_SUCCESS, outLen > 0 else { return "" }
        return String(decoding: fmtBuf[0..<min(outLen, fmtBuf.count)], as: UTF8.self)
    }

    /// The visible screen as a grid of cells with resolved color + attributes:
    /// the colored render path. Reads each cell via grid_ref (cell + style), the way
    /// ghostty's own renderer does, instead of the monochrome PLAIN formatter.
    private var cpBuf = [UInt32](repeating: 0, count: 16)
    public func screenCells() -> [[TermCell]] {
        guard let h = handle else { return [] }
        var colsU: UInt16 = 0, rowsU: UInt16 = 0
        _ = ghostty_terminal_get(h, GHOSTTY_TERMINAL_DATA_COLS, &colsU)
        _ = ghostty_terminal_get(h, GHOSTTY_TERMINAL_DATA_ROWS, &rowsU)
        let cols = Int(colsU), rows = Int(rowsU)
        guard cols > 0, rows > 0 else { return [] }

        let blank = TermCell(text: " ", fg: nil, bg: nil, bold: false, inverse: false, underline: false)
        var grid = [[TermCell]]()
        grid.reserveCapacity(rows)
        for y in 0..<rows {
            var rowCells = [TermCell]()
            rowCells.reserveCapacity(cols)
            for x in 0..<cols {
                // Build bottom-up: GhosttyPointValue is a C union, so its member
                // getter returns a copy, so chained mutation through it is lost.
                var coord = GhosttyPointCoordinate()
                coord.x = UInt16(x)
                coord.y = UInt32(y)
                var point = GhosttyPoint()
                point.tag = GHOSTTY_POINT_TAG_VIEWPORT
                point.value = GhosttyPointValue(coordinate: coord)
                var ref = GhosttyGridRef()
                guard ghostty_terminal_grid_ref(h, point, &ref) == GHOSTTY_SUCCESS, ref.node != nil else {
                    rowCells.append(blank); continue
                }
                // Grapheme text (primary codepoint + any combining marks).
                var n = 0
                let gres = cpBuf.withUnsafeMutableBufferPointer {
                    ghostty_grid_ref_graphemes(&ref, $0.baseAddress, $0.count, &n)
                }
                var text = " "
                if gres == GHOSTTY_SUCCESS, n > 0 {
                    var s = String.UnicodeScalarView()
                    for i in 0..<min(n, cpBuf.count) where cpBuf[i] != 0 {
                        if let u = Unicode.Scalar(cpBuf[i]) { s.append(u) }
                    }
                    let str = String(s)
                    if !str.isEmpty { text = str }
                }
                // Style (fg/bg color + attributes).
                var style = GhosttyStyle()
                _ = ghostty_grid_ref_style(&ref, &style)
                let flags = style.flags
                rowCells.append(TermCell(
                    text: text,
                    fg: Self.resolve(style.fg_color),
                    bg: Self.resolve(style.bg_color),
                    bold: flags & StyleFlag.bold != 0,
                    inverse: flags & StyleFlag.inverse != 0,
                    underline: flags & StyleFlag.underlineMask != 0
                ))
            }
            grid.append(rowCells)
        }
        return grid
    }

    /// GhosttyStyle.flags bits. style.h defines these as cast macros, which Swift
    /// doesn't import, so mirror them here.
    private enum StyleFlag {
        static let bold: GhosttyStyleFlags = 1 << 0
        static let inverse: GhosttyStyleFlags = 1 << 4
        static let underlineMask: GhosttyStyleFlags = 0x7 << 8
    }

    /// Resolve a style color (none / palette index / direct RGB) to concrete RGB.
    private static func resolve(_ c: GhosttyStyleColor) -> TermColor? {
        switch UInt32(c.tag) {
        case GHOSTTY_STYLE_COLOR_RGB.rawValue:
            return TermColor(r: c.value.rgb.r, g: c.value.rgb.g, b: c.value.rgb.b)
        case GHOSTTY_STYLE_COLOR_PALETTE.rawValue:
            let p = palette256[Int(c.value.palette)]
            return TermColor(r: p.0, g: p.1, b: p.2)
        default:
            return nil  // none -> terminal default fg/bg
        }
    }

    /// Standard xterm 256-color palette: 16 ANSI + 6×6×6 cube + 24 grays.
    private static let palette256: [(UInt8, UInt8, UInt8)] = {
        var p: [(UInt8, UInt8, UInt8)] = [
            (0, 0, 0), (205, 0, 0), (0, 205, 0), (205, 205, 0),
            (0, 0, 238), (205, 0, 205), (0, 205, 205), (229, 229, 229),
            (127, 127, 127), (255, 0, 0), (0, 255, 0), (255, 255, 0),
            (92, 92, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255),
        ]
        let levels: [UInt8] = [0, 95, 135, 175, 215, 255]
        for r in 0..<6 { for g in 0..<6 { for b in 0..<6 { p.append((levels[r], levels[g], levels[b])) } } }
        for i in 0..<24 { let c = UInt8(8 + i * 10); p.append((c, c, c)) }
        return p
    }()
}

/// A resolved cell color (RGB, 0-255 per channel).
public struct TermColor: Sendable, Equatable {
    public let r, g, b: UInt8
    public init(r: UInt8, g: UInt8, b: UInt8) { self.r = r; self.g = g; self.b = b }
}

/// One rendered terminal cell: its grapheme text plus resolved colors + attributes.
/// `fg`/`bg` are nil when the cell uses the terminal's default fg/bg.
public struct TermCell: Sendable {
    public let text: String
    public let fg: TermColor?
    public let bg: TermColor?
    public let bold: Bool
    public let inverse: Bool
    public let underline: Bool
}

public enum GhosttyVT {
    /// Linkage smoke test: libghostty-vt is linked and callable.
    public static func selfTest() -> Bool {
        guard let t = GhosttyTerminalVT(cols: 80, rows: 24) else { return false }
        t.write(Array("hello\r\n".utf8))
        return true
    }
}
