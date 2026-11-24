import Foundation
import SwiftUI
#if canImport(CloneClient)
import CloneClient
#endif

// Console: the macOS Console analog. On a systemd appliance the unified log is
// journald, so Console streams `journalctl -f` (like macOS reads os_log). Lines
// land in a scrollable, filterable List (now crash-safe).

// MARK: - State

// @unchecked Sendable: journalctl output arrives on a background reader; the
// mutation hops to main via DispatchQueue.main.async.
final class ConsoleState: @unchecked Sendable {
    private(set) var lines: [String] = []
    var filter: String = ""
    private var process: Process?
    private let maxLines = 2000

    init() {
        startTail()
    }

    var visibleLines: [String] {
        let f = filter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !f.isEmpty else { return lines }
        return lines.filter { $0.lowercased().contains(f) }
    }

    private func startTail() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        // -f follow, last 300 for context, short-iso for readable timestamps.
        p.arguments = ["journalctl", "-f", "-n", "300", "-o", "short-iso", "--no-hostname"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            let new = chunk.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            DispatchQueue.main.async {
                guard let self else { return }
                self.lines.append(contentsOf: new)
                if self.lines.count > self.maxLines {
                    self.lines.removeFirst(self.lines.count - self.maxLines)
                }
                requestRedraw()
            }
        }
        do { try p.run(); process = p } catch {
            lines = ["console: failed to start journalctl: \(error)"]
        }
    }
}

// MARK: - View

@MainActor func consoleView(state: ConsoleState, width: CGFloat, height: CGFloat) -> some View {
    // Adaptive colors: Console follows the system appearance, it doesn't pick one.
    let lines = state.visibleLines
    return ZStack {
        Rectangle()
            .fill(Color(nsColor: .windowBackgroundColor))
            .frame(width: width, height: height)
        VStack(alignment: .leading, spacing: 0) {
            // Filter bar
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(width: width - 24, height: 28)
                Text(state.filter.isEmpty ? "Filter…" : state.filter)
                    .font(.system(size: 12))
                    .foregroundColor(state.filter.isEmpty ? .secondary : .primary)
            }
            .padding(12)

            List {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line.isEmpty ? " " : line)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
            .frame(width: width, height: height - 52)
        }
        .frame(width: width, height: height)
    }
}

// MARK: - App

@main
struct ConsoleApp: App {
    let state = ConsoleState()

    var body: some Scene {
        WindowGroup("Console") {
            consoleView(state: state, width: 900, height: 560)
        }
    }

    #if canImport(CloneClient)
    var configuration: WindowConfiguration {
        WindowConfiguration(title: "Console", width: 900, height: 560, role: .window)
    }

    func onKeyChar(character: String) {
        if character == "\u{7f}" || character == "\u{08}" {
            if !state.filter.isEmpty { state.filter.removeLast() }
        } else if character.count == 1, let s = character.unicodeScalars.first, s.value >= 32 {
            state.filter.append(character)
        }
    }
    #endif
}
