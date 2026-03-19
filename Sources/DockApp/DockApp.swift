import Foundation
import SwiftUI

// MARK: - Dock Items

struct DockItem {
    let appId: String
    let name: String
    let color: Color
}

let items: [DockItem] = [
    DockItem(appId: "com.clone.finder", name: "Finder", color: .blue),
    DockItem(appId: "com.clone.safari", name: "Safari", color: .blue),
    DockItem(appId: "com.clone.mail", name: "Mail", color: .blue),
    DockItem(appId: "com.clone.music", name: "Music", color: .red),
    DockItem(appId: "com.clone.photos", name: "Photos", color: .green),
    DockItem(appId: "com.clone.terminal", name: "Terminal", color: .black),
    DockItem(appId: "com.clone.settings", name: "Settings", color: .gray),
]

// MARK: - Constants

let baseIconSize: Float = 48
let maxScale: Float = 2.0
let influenceRadius: Float = 150
let iconPadding: Float = 8
let dockHeight: Float = 64

// MARK: - State

class DockState {
    var mouseX: Float = 0
    var mouseY: Float = 0
    var minimizedAppIds: [String] = []
}

// MARK: - Magnification & Hit Testing

func magnifiedSizes(mouseX: Float, iconCount: Int, screenWidth: Float) -> [Float] {
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

// MARK: - Declarative Dock View

func dockView(state: DockState, width: Float, height: Float) -> some View {
    let sizes = magnifiedSizes(mouseX: state.mouseX, iconCount: items.count, screenWidth: width)
    let totalWidth = sizes.reduce(0, +) + Float(items.count - 1) * iconPadding + iconPadding * 2
    let bgHeight = dockHeight + iconPadding * 2
    let bgX = (width - totalWidth) / 2
    let bgY = height - bgHeight

    let hoveredIndex = hoveredIconIndex(
        mouseX: state.mouseX, mouseY: state.mouseY,
        iconCount: items.count, screenWidth: width, screenHeight: height
    )

    // Dock background pill
    var children = [
        RoundedRectangle(cornerRadius: 16)
            .fill(WindowChrome.dock)
            .frame(width: totalWidth, height: bgHeight)
            .padding(EdgeInsets(top: bgY, leading: bgX, bottom: 0, trailing: 0))
    ]

    // Icons, dots, and hover labels
    var iconX = bgX + iconPadding

    for (i, item) in items.enumerated() {
        let size = sizes[i]
        let iconY = bgY + bgHeight - iconPadding - size
        let cornerRadius = size * 0.22

        // Icon
        children.append(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(item.color)
                .frame(width: size, height: size)
                .padding(EdgeInsets(top: iconY, leading: iconX, bottom: 0, trailing: 0))
        )

        // Minimized indicator dot
        if state.minimizedAppIds.contains(item.appId) {
            let dotSize: Float = 4
            let dotX = iconX + size / 2 - dotSize / 2
            let dotY = bgY + bgHeight - iconPadding / 2
            children.append(
                RoundedRectangle(cornerRadius: dotSize / 2)
                    .fill(.primary)
                    .frame(width: dotSize, height: dotSize)
                    .padding(EdgeInsets(top: dotY, leading: dotX, bottom: 0, trailing: 0))
            )
        }

        // Hover label
        if i == hoveredIndex {
            let textWidth = Float(item.name.count) * 8 + 20
            let labelH: Float = 26
            let labelX = iconX + size / 2 - textWidth / 2
            let labelY = iconY - labelH - 6

            children.append(
                RoundedRectangle(cornerRadius: 6)
                    .fill(WindowChrome.popover)
                    .frame(width: textWidth, height: labelH)
                    .padding(EdgeInsets(top: labelY, leading: labelX, bottom: 0, trailing: 0))
            )
            children.append(
                Text(item.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(EdgeInsets(top: labelY + 6, leading: labelX + 10, bottom: 0, trailing: 0))
            )
        }

        iconX += size + iconPadding
    }

    return ZStack { children }
        .frame(width: width, height: height)
}

// MARK: - App Entry Point

@main
struct DockApp: App {
    let state = DockState()

    var body: some Scene {
        WindowGroup("Dock") {
            dockView(state: state, width: 1280, height: 800)
        }
    }

    var configuration: WindowConfiguration {
        WindowConfiguration(title: "Dock", width: 1280, height: 800, role: .dock)
    }

    func onPointerMove(x: Float, y: Float) {
        state.mouseX = x
        state.mouseY = y
    }

    func onPointerButton(button: UInt32, pressed: Bool, x: Float, y: Float) {
        if button == 0 && pressed {
            let index = hoveredIconIndex(mouseX: x, mouseY: y,
                                          iconCount: items.count,
                                          screenWidth: WindowState.shared.width, screenHeight: WindowState.shared.height)
            if let index {
                let item = items[index]
                if state.minimizedAppIds.contains(item.appId) {
                    SystemActions.shared.restoreApp(item.appId)
                } else {
                    SystemActions.shared.launchApp(item.appId)
                }
            }
        }
    }

    func onMinimizedApps(appIds: [String]) {
        state.minimizedAppIds = appIds
    }
}
