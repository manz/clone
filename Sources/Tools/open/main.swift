import Foundation
import CloneProtocol
import CloneLaunchServices

/// Clone's `open` command — opens files and launches app bundles via launchservicesd.
/// Usage: open <file|app.app> [file2 ...]
///        open -a <appname>
///        open -a <appname> <file>

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
    // Try as bundle identifier first, then as display name
    if lsClient.launch(bundleIdentifier: name) != nil {
        exit(0)
    }
    if lsClient.launch(bundleIdentifier: "com.clone.\(name.lowercased())") != nil {
        exit(0)
    }
    // Search all registered apps by display name
    let allApps = lsClient.allApps()
    if let match = allApps.first(where: { $0.displayName.caseInsensitiveCompare(name) == .orderedSame || $0.bundleName.caseInsensitiveCompare(name) == .orderedSame }) {
        if lsClient.launch(bundleIdentifier: match.bundleIdentifier) != nil {
            exit(0)
        }
    }
    fputs("open: no application named \"\(name)\"\n", stderr)
    exit(1)
}

// Case 2: open Foo.app — launch an app bundle directly
// Case 3: open file.txt — open a file with its default app
// Case 4: open -a AppName file.txt — open a file with a specific app

for file in files {
    let path = file.hasPrefix("/") ? file : FileManager.default.currentDirectoryPath + "/" + file

    // .app bundle — launch it directly via launchservicesd
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

    // Regular file — find the app to open it with
    guard FileManager.default.fileExists(atPath: path) else {
        fputs("open: \(file): No such file or directory\n", stderr)
        continue
    }

    let ext = (path as NSString).pathExtension.lowercased()

    let reg: AppRegistration?
    if let name = appName {
        reg = lsClient.appInfo(bundleIdentifier: name)
            ?? lsClient.appInfo(bundleIdentifier: "com.clone.\(name.lowercased())")
    } else {
        guard !ext.isEmpty else {
            fputs("open: \(file): no file extension, cannot determine app\n", stderr)
            continue
        }
        reg = lsClient.defaultApp(forExtension: ext)
    }

    guard let app = reg else {
        fputs("open: no application to open \(file)\n", stderr)
        continue
    }

    fputs("open: opening \(file) with \(app.displayName)\n", stderr)

    // Tell compositor to open the file in the app
    let compositorFd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard compositorFd >= 0 else {
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
            Foundation.connect(compositorFd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }

    if result == 0 {
        let registerMsg = AppMessage.register(appId: "com.clone.open", title: "open", width: 0, height: 0, role: .window)
        if let data = try? WireProtocol.encode(registerMsg) {
            data.withUnsafeBytes { _ = write(compositorFd, $0.baseAddress!, data.count) }
        }
        let openMsg = AppMessage.openFile(path: path)
        if let data = try? WireProtocol.encode(openMsg) {
            data.withUnsafeBytes { _ = write(compositorFd, $0.baseAddress!, data.count) }
        }
        let closeMsg = AppMessage.close
        if let data = try? WireProtocol.encode(closeMsg) {
            data.withUnsafeBytes { _ = write(compositorFd, $0.baseAddress!, data.count) }
        }
    } else {
        fputs("open: cannot connect to compositor\n", stderr)
    }
    close(compositorFd)
}
