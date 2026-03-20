import Foundation
import SwiftUI
#if canImport(CloneClient)
import CloneClient
#endif

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

let baseIconSize: CGFloat = 48
let maxScale: CGFloat = 1.8
let influenceRadius: CGFloat = 120
let iconPadding: CGFloat = 8
let dockHeight: CGFloat = 64

// MARK: - State

class DockState {
    var minimizedAppIds: [String] = []
    var hoveredAppId: String? = nil
    var mouseX: CGFloat = 0
    var dockHovered: Bool = false
}

// MARK: - Magnification

func magnifiedSize(index: Int, mouseX: CGFloat, totalBaseWidth: CGFloat, startX: CGFloat) -> CGFloat {
    let iconCenterX = startX + CGFloat(index) * (baseIconSize + iconPadding) + baseIconSize / 2
    let distance = abs(mouseX - iconCenterX)
    if distance > influenceRadius { return baseIconSize }
    let t = 1.0 - (distance / influenceRadius)
    let scale = 1.0 + (maxScale - 1.0) * (1.0 - cos(t * .pi)) / 2.0
    return baseIconSize * scale
}

// MARK: - Dock Icon

func dockIcon(state: DockState, item: DockItem, size: CGFloat) -> some View {
    let cornerRadius = size * 0.22
    let isHovered = state.hoveredAppId == item.appId

    return VStack(spacing: 4) {
        if isHovered {
            ZStack {
                let textWidth = CGFloat(item.name.count) * 8 + 20
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.adaptive(dark: Color(red: 0.15, green: 0.15, blue: 0.16, opacity: 0.95),
                                        light: Color(red: 0.98, green: 0.98, blue: 0.98, opacity: 0.95)))
                    .frame(width: textWidth, height: 26)
                Text(item.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(height: 26)
        }
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(item.color)
            .frame(width: size, height: size)
            .onHover { hovered in
                state.hoveredAppId = hovered ? item.appId : nil
            }
            .onTapGesture {
                #if canImport(CloneClient)
                if state.minimizedAppIds.contains(item.appId) {
                    SystemActions.shared.restoreApp(item.appId)
                } else {
                    SystemActions.shared.launchApp(item.appId)
                }
                #endif
            }
    }
}

// MARK: - Declarative Dock View

func dockView(state: DockState, width: CGFloat, height: CGFloat) -> some View {
    let totalBaseWidth = CGFloat(items.count) * baseIconSize + CGFloat(items.count - 1) * iconPadding
    let startX = (width - totalBaseWidth) / 2

    let sizes: [CGFloat] = items.enumerated().map { i, _ in
        state.dockHovered ? magnifiedSize(index: i, mouseX: state.mouseX, totalBaseWidth: totalBaseWidth, startX: startX) : baseIconSize
    }
    let totalIconWidth = sizes.reduce(0, +) + CGFloat(items.count - 1) * iconPadding
    let totalWidth = totalIconWidth + iconPadding * 2
    let bgHeight = dockHeight + iconPadding * 2
    let maxSize = sizes.max() ?? baseIconSize
    let zoneHeight = maxSize + (state.hoveredAppId != nil ? 34 : 0) + iconPadding * 2

    return VStack(spacing: 0) {
        Spacer()
        ZStack {
            // Pill anchored to bottom
            VStack(spacing: 0) {
                Spacer()
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.adaptive(dark: Color(red: 0.2, green: 0.2, blue: 0.2, opacity: 0.6),
                                        light: Color(red: 0.95, green: 0.95, blue: 0.95, opacity: 0.7)))
                    .frame(width: totalWidth, height: bgHeight)
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let pt):
                            state.dockHovered = true
                            state.mouseX = pt.x
                        case .ended:
                            state.dockHovered = false
                            state.hoveredAppId = nil
                        }
                    }
            }
            // Icons anchored to bottom
            VStack(spacing: 0) {
                Spacer()
                HStack(alignment: .bottom, spacing: iconPadding) {
                    ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                        dockIcon(state: state, item: item, size: sizes[i])
                    }
                }
                .padding(.bottom, iconPadding)
            }
        }
        .frame(width: totalWidth, height: zoneHeight)
    }
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

    #if canImport(CloneClient)
    var configuration: WindowConfiguration {
        WindowConfiguration(title: "Dock", width: 1280, height: 800, role: .dock)
    }

    func onMinimizedApps(appIds: [String]) {
        state.minimizedAppIds = appIds
    }
    #endif
}
