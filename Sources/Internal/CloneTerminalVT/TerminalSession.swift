import CPty
import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// A live terminal: spawns a shell on a PTY, reads its output into a
/// libghostty-vt instance, and exposes the screen as text + an input sink.
/// The Terminal app drives this: start(), send() on keystrokes, screenText()
/// to render, resize() on window resize.
// @unchecked Sendable: the read loop runs on a background thread while the app
// sends/resizes from the main thread. libghostty-vt isn't reentrant, so a later
// pass should serialize vt access; for v1 the fd ops + append are acceptable.
public final class TerminalSession: @unchecked Sendable {
    private let vt: GhosttyTerminalVT
    private var masterFd: Int32 = -1
    private var childPid: pid_t = -1
    private var cols: UInt16
    private var rows: UInt16
    private var running = false

    /// Called (on a background thread) after new output is processed, to redraw.
    public var onUpdate: (() -> Void)?

    public init?(cols: UInt16 = 80, rows: UInt16 = 24) {
        guard let vt = GhosttyTerminalVT(cols: cols, rows: rows) else { return nil }
        self.vt = vt
        self.cols = cols
        self.rows = rows
    }

    /// Spawn the shell and start the read loop.
    public func start(shell: String = "/bin/bash") {
        var master: Int32 = -1
        let argv0 = strdup(shell)
        defer { free(argv0) }
        var argv: [UnsafeMutablePointer<CChar>?] = [argv0, nil]

        // Child env: inherit, but force a real terminal type. Without TERM zsh's
        // line editor (ZLE) runs degraded (cursor stuck, no editing) and color
        // apps fall back to monochrome.
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        var envp: [UnsafeMutablePointer<CChar>?] = env.map { strdup("\($0.key)=\($0.value)") }
        envp.append(nil)
        defer { for p in envp where p != nil { free(p) } }

        let pid = shell.withCString { sh in
            argv.withUnsafeMutableBufferPointer { argvBuf in
                envp.withUnsafeMutableBufferPointer { envBuf in
                    clone_pty_spawn(sh, argvBuf.baseAddress, envBuf.baseAddress, rows, cols, &master)
                }
            }
        }
        guard pid > 0, master >= 0 else { return }
        masterFd = master
        childPid = pid
        running = true
        let t = Thread { [weak self] in self?.readLoop() }
        t.stackSize = 1 << 20
        t.start()
    }

    private func readLoop() {
        var buf = [UInt8](repeating: 0, count: 16 * 1024)
        while running {
            let n = read(masterFd, &buf, buf.count)
            if n <= 0 { break }
            buf.withUnsafeBufferPointer { vt.write(UnsafeBufferPointer(rebasing: $0[0..<n])) }
            onUpdate?()
        }
    }

    /// Send user input (UTF-8 text or an escape sequence) to the shell.
    public func send(_ s: String) { send(Array(s.utf8)) }

    public func send(_ bytes: [UInt8]) {
        guard masterFd >= 0, !bytes.isEmpty else { return }
        bytes.withUnsafeBufferPointer { _ = write(masterFd, $0.baseAddress, $0.count) }
    }

    public func resize(cols: UInt16, rows: UInt16) {
        self.cols = cols
        self.rows = rows
        vt.resize(cols: cols, rows: rows)
        if masterFd >= 0 { _ = clone_pty_set_winsize(masterFd, rows, cols) }
    }

    /// Scroll the viewport by `lines` (negative = into scrollback history).
    public func scroll(lines: Int) {
        vt.scrollViewport(lines: lines)
        onUpdate?()
    }

    /// The visible screen as plain text (v1 render).
    public func screenText() -> String { vt.screenText() }

    /// The visible screen as a grid of colored cells (the colored render path).
    public func screenCells() -> [[TermCell]] { vt.screenCells() }

    /// Cursor position (col, row) in the active screen.
    public var cursor: (col: Int, row: Int) { vt.cursor }

    /// Whether the cursor should be drawn (apps like htop hide it).
    public var cursorVisible: Bool { vt.cursorVisible }

    public var size: (cols: UInt16, rows: UInt16) { (cols, rows) }

    public func stop() {
        running = false
        if masterFd >= 0 { close(masterFd); masterFd = -1 }
    }

    deinit { stop() }
}
