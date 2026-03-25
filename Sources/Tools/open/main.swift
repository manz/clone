import Foundation
import CloneProtocol
import CloneLaunchServices
import AvocadoEvents

/// Clone's `open` command — opens files and launches app bundles.
///
/// Mirrors macOS `open`:
///   open file.txt          — launchservicesd resolves default app, launches it, routes file via avocadoeventsd
///   open Foo.app           — launchservicesd launches the bundle
///   open -a AppName        — launchservicesd launches by name
///   open -a AppName file   — launchservicesd resolves app, launches it, routes file via avocadoeventsd

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

// Route files to apps via AvocadoEvents
if !filesToRoute.isEmpty {
    let aeClient = AvocadoEventsClient()
    do {
        try aeClient.connect()
    } catch {
        fputs("open: cannot connect to avocadoeventsd: \(error)\n", stderr)
        exit(1)
    }

    // Group by target app
    var byApp: [String: [String]] = [:]
    for (path, appId) in filesToRoute {
        byApp[appId, default: []].append(path)
    }

    // avocadoeventsd buffers events for apps that haven't connected yet,
    // so no sleep needed — the event will be delivered when the app registers.
    for (appId, paths) in byApp {
        aeClient.send(to: appId, event: .openDocuments(paths: paths))
    }

    aeClient.disconnect()
}
