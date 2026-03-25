import Foundation
import CloneProtocol
import CloneLaunchServices

/// Clone's `open` command — opens files with their default application via launchservicesd.
/// Usage: open <file> [file2 ...]
///        open -a <appname> <file>

let args = CommandLine.arguments.dropFirst()

guard !args.isEmpty else {
    fputs("Usage: open [-a application] file ...\n", stderr)
    exit(1)
}

var appBundleId: String?
var files: [String] = []
var i = args.startIndex
while i < args.endIndex {
    if args[i] == "-a" {
        i = args.index(after: i)
        guard i < args.endIndex else {
            fputs("open: -a requires an argument\n", stderr)
            exit(1)
        }
        appBundleId = args[i]
    } else {
        files.append(args[i])
    }
    i = args.index(after: i)
}

guard !files.isEmpty else {
    fputs("open: no files specified\n", stderr)
    exit(1)
}

// Connect to launchservicesd
let client = LaunchServicesClient()
do {
    try client.connect()
} catch {
    fputs("open: cannot connect to launchservicesd: \(error)\n", stderr)
    exit(1)
}

for file in files {
    let path = file.hasPrefix("/") ? file : FileManager.default.currentDirectoryPath + "/" + file

    guard FileManager.default.fileExists(atPath: path) else {
        fputs("open: \(file): No such file or directory\n", stderr)
        continue
    }

    let ext = (path as NSString).pathExtension.lowercased()

    // Find the app to open with
    let reg: AppRegistration?
    if let bundleId = appBundleId {
        reg = client.appInfo(bundleIdentifier: bundleId)
            ?? client.appInfo(bundleIdentifier: "com.clone.\(bundleId.lowercased())")
    } else {
        guard !ext.isEmpty else {
            fputs("open: \(file): no file extension, cannot determine app\n", stderr)
            continue
        }
        reg = client.defaultApp(forExtension: ext)
    }

    guard let app = reg else {
        fputs("open: no application to open \(file)\n", stderr)
        continue
    }

    fputs("open: opening \(file) with \(app.displayName)\n", stderr)

    // Send openFile to compositor via IPC
    // The open command connects directly to the compositor to request file opening
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
        // Register as a transient app, then send openFile
        let registerMsg = AppMessage.register(appId: "com.clone.open", title: "open", width: 0, height: 0, role: .window)
        if let data = try? WireProtocol.encode(registerMsg) {
            data.withUnsafeBytes { _ = write(compositorFd, $0.baseAddress!, data.count) }
        }
        let openMsg = AppMessage.openFile(path: path)
        if let data = try? WireProtocol.encode(openMsg) {
            data.withUnsafeBytes { _ = write(compositorFd, $0.baseAddress!, data.count) }
        }
        // Send close immediately — we're a one-shot command
        let closeMsg = AppMessage.close
        if let data = try? WireProtocol.encode(closeMsg) {
            data.withUnsafeBytes { _ = write(compositorFd, $0.baseAddress!, data.count) }
        }
    } else {
        fputs("open: cannot connect to compositor\n", stderr)
    }
    close(compositorFd)
}
