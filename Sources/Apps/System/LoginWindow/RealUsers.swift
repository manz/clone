import Foundation

// The real (pickable) desktop users shown in LoginWindow, like the macOS loginwindow
// user list. The source of truth is /Users (like macOS): each home dir is a real
// account. System accounts (_windowserver) and admin (dev) live elsewhere
// (/var/lib, /home), so they never appear here.
enum RealUsers {
    static var directory: String {
        ProcessInfo.processInfo.environment["CLONE_REALUSERS_DIR"] ?? "/Users"
    }

    // macOS /Users also holds "Shared" and ".localized", which are not accounts.
    private static let excluded: Set<String> = ["Shared", "Guest"]

    static func list() -> [String] {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: directory) else { return [] }
        return names
            .filter { !$0.hasPrefix(".") && !excluded.contains($0) }
            .filter { var isDir: ObjCBool = false
                      return fm.fileExists(atPath: "\(directory)/\($0)", isDirectory: &isDir) && isDir.boolValue }
            .sorted()
    }
}
