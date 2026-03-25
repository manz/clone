import Foundation
import CloneProtocol
import CloneLaunchServices

/// Clone's `open` command — opens files and launches app bundles.
///
/// Mirrors macOS `open`:
///   open file.txt          — launchservicesd resolves default app, launches it, routes file via AvocadoEvent
///   open Foo.app           — launchservicesd launches the bundle
///   open -a AppName        — launchservicesd launches by name
///   open -a AppName file   — launchservicesd resolves app, launches it, routes file via AvocadoEvent

let args = Array(CommandLine.arguments.dropFirst())

guard !args.isEmpty else {
    fputs("Usage: open [-a application] file ...\n", stderr)
    fputs("       open <app.app>\n", stderr)
    exit(1)
}

var appName: String?
var files: [String] = []
var i = 0
while i < args.count {
    if args[i] == "-a" {
        i += 1
        guard i < args.count else {
            fputs("open: -a requires an argument\n", stderr)
            exit(1)
        }
        appName = args[i]
    } else {
        files.append(args[i])
    }
    i += 1
}

// Connect to launchservicesd
let lsClient = LaunchServicesClient()
do {
    try lsClient.connect()
} catch {
    fputs("open: cannot connect to launchservicesd: \(error)\n", stderr)
    exit(1)
}

// Case 1: open -a AppName (no file) — launch by name
if let name = appName, files.isEmpty {
    if lsClient.launch(bundleIdentifier: name) != nil { exit(0) }
    if lsClient.launch(bundleIdentifier: "com.clone.\(name.lowercased())") != nil { exit(0) }
    let allApps = lsClient.allApps()
    if let match = allApps.first(where: { $0.displayName.caseInsensitiveCompare(name) == .orderedSame || $0.bundleName.caseInsensitiveCompare(name) == .orderedSame }) {
        if lsClient.launch(bundleIdentifier: match.bundleIdentifier) != nil { exit(0) }
    }
    fputs("open: no application named \"\(name)\"\n", stderr)
    exit(1)
}

// Collect files that need routing to apps
var filesToRoute: [(path: String, appId: String)] = []

for file in files {
    let path = file.hasPrefix("/") ? file : FileManager.default.currentDirectoryPath + "/" + file

    // .app bundle — launch directly via launchservicesd
    if path.hasSuffix(".app") {
        guard FileManager.default.fileExists(atPath: path) else {
            fputs("open: \(file): No such file or directory\n", stderr)
            continue
        }
        if lsClient.launchBundle(path: path) != nil {
            fputs("open: launching \(file)\n", stderr)
        } else {
            fputs("open: failed to launch \(file)\n", stderr)
        }
        continue
    }

    // Regular file — resolve + launch via launchservicesd
    guard FileManager.default.fileExists(atPath: path) else {
        fputs("open: \(file): No such file or directory\n", stderr)
        continue
    }

    guard let reg = lsClient.openFile(path: path, withApp: appName) else {
        fputs("open: no application to open \(file)\n", stderr)
        continue
    }

    fputs("open: opening \(file) with \(reg.displayName)\n", stderr)
    filesToRoute.append((path: path, appId: reg.bundleIdentifier))
}

// Route files to apps via AvocadoEvents through the compositor
if !filesToRoute.isEmpty {
    // Group by target app
    var byApp: [String: [String]] = [:]
    for (path, appId) in filesToRoute {
        byApp[appId, default: []].append(path)
    }

    // Connect to compositor as a service (no window, just event routing)
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
        fputs("open: cannot create socket\n", stderr)
        exit(1)
    }

    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    compositorSocketPath.withCString { ptr in
        withUnsafeMutablePointer(to: &addr.sun_path) { pathPtr in
            pathPtr.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
                _ = strlcpy(dest, ptr, 104)
            }
        }
    }

    let result = withUnsafePointer(to: &addr) { ptr in
        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
            Foundation.connect(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }

    guard result == 0 else {
        fputs("open: cannot connect to compositor for AvocadoEvent routing\n", stderr)
        close(fd)
        exit(1)
    }

    // Register as a service — no window surface
    let registerMsg = AppMessage.register(appId: "com.clone.open", title: "open", width: 0, height: 0, role: .service)
    if let data = try? WireProtocol.encode(registerMsg) {
        data.withUnsafeBytes { _ = write(fd, $0.baseAddress!, data.count) }
    }

    // Brief wait for registration
    usleep(50_000)

    // Send AvocadoEvents to each target app
    for (appId, paths) in byApp {
        let event = AppMessage.avocadoEvent(targetAppId: appId, event: .openDocuments(paths: paths))
        if let data = try? WireProtocol.encode(event) {
            data.withUnsafeBytes { _ = write(fd, $0.baseAddress!, data.count) }
        }
    }

    // Clean disconnect
    let closeMsg = AppMessage.close
    if let data = try? WireProtocol.encode(closeMsg) {
        data.withUnsafeBytes { _ = write(fd, $0.baseAddress!, data.count) }
    }
    close(fd)
}
