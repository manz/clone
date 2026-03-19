import Foundation
import CloneClient
import CloneProtocol

struct DockItem {
    let appId: String
    let name: String
    let r: Float, g: Float, b: Float
}

let items: [DockItem] = [
    DockItem(appId: "com.clone.finder", name: "Finder", r: 0.19, g: 0.55, b: 0.91),
    DockItem(appId: "com.clone.safari", name: "Safari", r: 0.19, g: 0.55, b: 0.91),
    DockItem(appId: "com.clone.mail", name: "Mail", r: 0.19, g: 0.55, b: 0.91),
    DockItem(appId: "com.clone.music", name: "Music", r: 0.92, g: 0.29, b: 0.35),
    DockItem(appId: "com.clone.photos", name: "Photos", r: 0.18, g: 0.75, b: 0.49),
    DockItem(appId: "com.clone.terminal", name: "Terminal", r: 0.0, g: 0.0, b: 0.0),
    DockItem(appId: "com.clone.settings", name: "Settings", r: 0.42, g: 0.39, b: 0.47),
]

let baseIconSize: Float = 48
let maxScale: Float = 2.0
let influenceRadius: Float = 150
let iconPadding: Float = 8
let dockHeight: Float = 64

var mouseX: Float = 0
var mouseY: Float = 0
var minimizedAppIds: [String] = []

let client = AppClient()

func render(width: Float, height: Float) -> [IPCRenderCommand] {
    var commands: [IPCRenderCommand] = []

    let sizes = magnifiedSizes(mouseX: mouseX, iconCount: items.count, screenWidth: width)
    let totalWidth = sizes.reduce(0, +) + Float(items.count - 1) * iconPadding + iconPadding * 2
    let bgHeight = dockHeight + iconPadding * 2

    // Dock background
    let bgX = (width - totalWidth) / 2
    let bgY = height - bgHeight
    commands.append(.roundedRect(
        x: bgX, y: bgY, w: totalWidth, h: bgHeight, radius: 16,
        color: IPCColor(r: 0.2, g: 0.2, b: 0.2, a: 0.6)
    ))

    // Icons
    var iconX = bgX + iconPadding
    let hoveredIndex = hoveredIconIndex(mouseX: mouseX, mouseY: mouseY,
                                         iconCount: items.count, screenWidth: width, screenHeight: height)

    for (i, item) in items.enumerated() {
        let size = sizes[i]
        let iconY = bgY + bgHeight - iconPadding - size
        let radius = size * 0.22

        commands.append(.roundedRect(
            x: iconX, y: iconY, w: size, h: size, radius: radius,
            color: IPCColor(r: item.r, g: item.g, b: item.b, a: 1)
        ))

        // Minimized indicator dot
        if minimizedAppIds.contains(item.appId) {
            let dotSize: Float = 4
            let dotX = iconX + size / 2 - dotSize / 2
            let dotY = bgY + bgHeight - iconPadding / 2
            commands.append(.roundedRect(
                x: dotX, y: dotY, w: dotSize, h: dotSize, radius: dotSize / 2,
                color: IPCColor(r: 0.88, g: 0.85, b: 0.91, a: 0.8)
            ))
        }

        // Popover label on hover
        if i == hoveredIndex {
            let textWidth = Float(item.name.count) * 8 + 20
            let labelH: Float = 26
            let labelX = iconX + size / 2 - textWidth / 2
            let labelY = iconY - labelH - 6
            commands.append(.roundedRect(
                x: labelX, y: labelY, w: textWidth, h: labelH, radius: 6,
                color: IPCColor(r: 0.15, g: 0.14, b: 0.20, a: 0.95)
            ))
            commands.append(.text(
                x: labelX + 10, y: labelY + 6,
                content: item.name, fontSize: 12,
                color: IPCColor(r: 1, g: 1, b: 1, a: 1), weight: .medium
            ))
        }

        iconX += size + iconPadding
    }

    return commands
}

func magnifiedSizes(mouseX: Float, iconCount: Int, screenWidth: Float) -> [Float] {
    // Only magnify when mouse is near the dock Y zone (handled by compositor mouse routing)
    let totalBaseWidth = Float(iconCount) * baseIconSize + Float(iconCount - 1) * iconPadding
    let startX = (screenWidth - totalBaseWidth) / 2

    return (0..<iconCount).map { i in
        let iconCenterX = startX + Float(i) * (baseIconSize + iconPadding) + baseIconSize / 2
        let distance = abs(mouseX - iconCenterX)
        if distance > influenceRadius { return baseIconSize }
        let t = 1.0 - (distance / influenceRadius)
        let scale = 1.0 + (maxScale - 1.0) * (1.0 - cosf(t * .pi)) / 2.0
        return baseIconSize * scale
    }
}

func hoveredIconIndex(mouseX: Float, mouseY: Float, iconCount: Int, screenWidth: Float, screenHeight: Float) -> Int? {
    let bgHeight = dockHeight + iconPadding * 2
    let bgY = screenHeight - bgHeight
    guard mouseY >= bgY && mouseY <= screenHeight else { return nil }

    let totalBaseWidth = Float(iconCount) * baseIconSize + Float(iconCount - 1) * iconPadding
    let startX = (screenWidth - totalBaseWidth) / 2

    for i in 0..<iconCount {
        let iconLeft = startX + Float(i) * (baseIconSize + iconPadding)
        if mouseX >= iconLeft && mouseX <= iconLeft + baseIconSize {
            return i
        }
    }
    return nil
}

// MARK: - Connect

do {
    try client.connect(appId: "com.clone.dock", title: "Dock", width: 1280, height: 800, role: .dock)
} catch {
    fputs("Dock: failed to connect: \(error)\n", stderr)
    exit(1)
}

client.onFrameRequest = { width, height in
    render(width: width, height: height)
}

client.onPointerMove = { x, y in
    mouseX = x
    mouseY = y
}

client.onPointerButton = { button, pressed, x, y in
    if button == 0 && pressed {
        let index = hoveredIconIndex(mouseX: x, mouseY: y,
                                      iconCount: items.count,
                                      screenWidth: client.width, screenHeight: client.height)
        if let index {
            let item = items[index]
            // If minimized, restore. Otherwise launch.
            if minimizedAppIds.contains(item.appId) {
                client.send(.restoreApp(appId: item.appId))
            } else {
                client.send(.launchApp(appId: item.appId))
            }
        }
    }
}

// Handle minimized app notifications
client.onMinimizedApps = { appIds in
    minimizedAppIds = appIds
}

fputs("Dock connected\n", stderr)
client.runLoop()
