import Foundation
import SwiftUI
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
#if canImport(CloneClient)
import CloneClient
#endif

// Activity Monitor - the macOS analog. Reads /proc for a live process list
// (CPU%, memory), refreshed on a timer, the way macOS reads the kernel task list.

struct ProcRow: Identifiable {
    let id: Int        // pid
    let name: String
    let cpu: Double     // percent
    let memMB: Double   // resident
}

// @unchecked Sendable: the timer fires on the main runloop; the read is synchronous.
final class ActivityState: @unchecked Sendable {
    private(set) var rows: [ProcRow] = []
    private(set) var memUsedMB: Double = 0
    private(set) var memTotalMB: Double = 0
    private(set) var loadAvg: String = ""
    private var prevCpu: [Int: UInt64] = [:]
    private var prevTotal: UInt64 = 0
    private let pageKB = Double(getpagesize()) / 1024.0
    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    /// Total CPU jiffies across all states (the "cpu " line of /proc/stat).
    private func totalCpuJiffies() -> UInt64 {
        guard let stat = try? String(contentsOfFile: "/proc/stat", encoding: .utf8),
              let line = stat.split(separator: "\n").first(where: { $0.hasPrefix("cpu ") }) else { return 0 }
        return line.split(separator: " ").dropFirst().compactMap { UInt64($0) }.reduce(0, +)
    }

    func refresh() {
        let total = totalCpuJiffies()
        let dTotal = total > prevTotal ? Double(total - prevTotal) : 1
        var newRows: [ProcRow] = []
        var newPrev: [Int: UInt64] = [:]
        let pids = (try? FileManager.default.contentsOfDirectory(atPath: "/proc")) ?? []
        for entry in pids {
            guard let pid = Int(entry),
                  let stat = try? String(contentsOfFile: "/proc/\(pid)/stat", encoding: .utf8),
                  // comm sits in parens and can contain spaces/parens; split around the last ')'.
                  let open = stat.firstIndex(of: "("), let close = stat.lastIndex(of: ")") else { continue }
            let name = String(stat[stat.index(after: open)..<close])
            // After the ')' the fields are: state(f3) ... utime(f14) stime(f15) ... rss(f24).
            // Index = field - 3, so utime=after[11], stime=after[12], rss=after[21].
            let after = stat[stat.index(after: close)...].split(separator: " ")
            guard after.count > 21 else { continue }
            let cpu = (UInt64(after[11]) ?? 0) + (UInt64(after[12]) ?? 0)
            let rssPages = Double(after[21]) ?? 0
            newPrev[pid] = cpu
            let dCpu = prevCpu[pid].map { cpu > $0 ? Double(cpu - $0) : 0 } ?? 0
            newRows.append(ProcRow(id: pid, name: name, cpu: dCpu / dTotal * 100.0,
                                   memMB: rssPages * pageKB / 1024.0))
        }
        newRows.sort { $0.cpu > $1.cpu }

        var memTotal = 0.0, memAvail = 0.0
        if let mi = try? String(contentsOfFile: "/proc/meminfo", encoding: .utf8) {
            for line in mi.split(separator: "\n") {
                let kb = Double(line.split(separator: " ").dropFirst().first ?? "0") ?? 0
                if line.hasPrefix("MemTotal:") { memTotal = kb / 1024 }
                if line.hasPrefix("MemAvailable:") { memAvail = kb / 1024 }
            }
        }
        let load = (try? String(contentsOfFile: "/proc/loadavg", encoding: .utf8))?
            .split(separator: " ").prefix(3).joined(separator: " ") ?? ""

        DispatchQueue.main.async { [self] in
            prevCpu = newPrev
            prevTotal = total
            rows = newRows
            memTotalMB = memTotal
            memUsedMB = memTotal - memAvail
            loadAvg = load
            requestRedraw()
        }
    }
}

// MARK: - View

@MainActor func activityView(state: ActivityState, width: CGFloat, height: CGFloat) -> some View {
    let nameW = width - 290
    return ZStack {
        Rectangle()
            .fill(Color(nsColor: .windowBackgroundColor))
            .frame(width: width, height: height)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Memory  \(Int(state.memUsedMB)) / \(Int(state.memTotalMB)) MB")
                Spacer()
                Text("Load  \(state.loadAvg)")
            }
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .frame(width: width - 24)
            .padding(12)

            HStack(spacing: 0) {
                Text("PID").frame(width: 70, alignment: .leading)
                Text("Process").frame(width: nameW, alignment: .leading)
                Text("% CPU").frame(width: 80, alignment: .trailing)
                Text("Mem MB").frame(width: 100, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)

            List {
                ForEach(state.rows) { p in
                    HStack(spacing: 0) {
                        Text("\(p.id)").frame(width: 70, alignment: .leading)
                        Text(p.name).frame(width: nameW, alignment: .leading)
                        Text(String(format: "%.1f", p.cpu)).frame(width: 80, alignment: .trailing)
                        Text(String(format: "%.1f", p.memMB)).frame(width: 100, alignment: .trailing)
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.primary)
                }
            }
            .frame(width: width, height: height - 84)
        }
        .frame(width: width, height: height)
    }
}

// MARK: - App

@main
struct ActivityMonitorApp: App {
    let state = ActivityState()

    var body: some Scene {
        WindowGroup("Activity Monitor") {
            activityView(state: state, width: 760, height: 560)
        }
    }

    #if canImport(CloneClient)
    var configuration: WindowConfiguration {
        WindowConfiguration(title: "Activity Monitor", width: 760, height: 560, role: .window)
    }
    #endif
}
