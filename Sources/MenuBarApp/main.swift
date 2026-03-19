import Foundation
import CloneClient
import CloneProtocol

var focusedAppName = "Finder"

let menuItems = ["File", "Edit", "View", "Window", "Help"]

let client = AppClient()

func render(width: Float, height: Float) -> [IPCRenderCommand] {
    var commands: [IPCRenderCommand] = []
    let barHeight: Float = 24
    let bg = IPCColor(r: 0.1, g: 0.1, b: 0.1, a: 0.5)
    let white = IPCColor(r: 1, g: 1, b: 1, a: 1)
    let textColor = IPCColor(r: 0.88, g: 0.85, b: 0.91, a: 1)

    // Background
    commands.append(.roundedRect(x: 0, y: 0, w: width, h: barHeight, radius: 0, color: bg))

    // Apple logo placeholder
    var x: Float = 12
    commands.append(.text(x: x, y: 5, content: "\u{F8FF}", fontSize: 14, color: white, weight: .regular))
    x += 24

    // App name (bold)
    commands.append(.text(x: x, y: 5.5, content: focusedAppName, fontSize: 13, color: white, weight: .bold))
    x += Float(focusedAppName.count) * 8 + 16

    // Menu items
    for item in menuItems {
        commands.append(.text(x: x, y: 5.5, content: item, fontSize: 13, color: textColor, weight: .regular))
        x += Float(item.count) * 8 + 16
    }

    // Clock — right aligned
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    let clock = formatter.string(from: Date())
    let clockX = width - Float(clock.count) * 8 - 12
    commands.append(.text(x: clockX, y: 5.5, content: clock, fontSize: 13, color: white, weight: .regular))

    return commands
}

// MARK: - Connect

do {
    try client.connect(appId: "com.clone.menubar", title: "MenuBar", width: 1280, height: 24, role: .menubar)
} catch {
    fputs("MenuBar: failed to connect: \(error)\n", stderr)
    exit(1)
}

client.onFrameRequest = { width, height in
    render(width: width, height: height)
}

client.onFocusedApp = { name in
    focusedAppName = name
}

fputs("MenuBar connected\n", stderr)
client.runLoop()
