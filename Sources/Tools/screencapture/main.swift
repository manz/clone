import Foundation
import CloneClient
import CloneProtocol

// macOS-style `screencapture`: write the composited screen to a PNG. The compositor
// owns the framebuffer, so this connects as a service client and asks it to capture
// (AppMessage.captureScreen) rather than reading the screen itself.
//
//   screencapture [output.png]   (defaults to ./screenshot.png)

let args = CommandLine.arguments
let out = args.count > 1 ? args[1] : "screenshot.png"
let path = out.hasPrefix("/") ? out : FileManager.default.currentDirectoryPath + "/" + out

// A fresh capture overwrites any stale file; remove first so we can tell it worked.
try? FileManager.default.removeItem(atPath: path)

let client = AppClient()
do {
    try client.connect(appId: "com.clone.screencapture", title: "screencapture",
                       width: 1, height: 1, role: .service)
    client.send(.captureScreen(path: path))
    // Give the compositor a few frames to render + write the PNG.
    Thread.sleep(forTimeInterval: 0.6)
    if FileManager.default.fileExists(atPath: path) {
        print("Screenshot written to \(path)")
    } else {
        FileHandle.standardError.write(Data("screencapture: no file produced (is the compositor running?)\n".utf8))
        exit(1)
    }
} catch {
    FileHandle.standardError.write(Data("screencapture: \(error)\n".utf8))
    exit(1)
}
