import Foundation
import SwiftUI
#if canImport(CloneClient)
import CloneClient
#endif
#if canImport(CloneProtocol)
import CloneProtocol
#endif
#if canImport(CloneRender)
import CloneRender
#endif

// MARK: - Dock Items

struct DockItem: Identifiable {
    let appId: String
    let name: String
    let icon: String
    let color: Color
    var id: String { appId }
}

let pinnedItems: [DockItem] = [
    DockItem(appId: "com.clone.finder", name: "Finder", icon: "folder.fill", color: .blue),
    DockItem(appId: "com.clone.settings", name: "Settings", icon: "gear.fill", color: .gray),
    DockItem(appId: "com.clone.textedit", name: "TextEdit", icon: "doc.text.fill", color: .orange),
    DockItem(appId: "com.clone.preview", name: "Preview", icon: "photo.fill", color: .green),
    DockItem(appId: "com.clone.password", name: "Password", icon: "lock.fill", color: .purple),
]

/// Icon/color fallback for apps that aren't in the pinned list.
let appCatalog: [String: (icon: String, color: Color)] = [
    "com.clone.finder": ("folder.fill", .blue),
    "com.clone.settings": ("gear.fill", .gray),
    "com.clone.textedit": ("doc.text.fill", .orange),
    "com.clone.preview": ("photo.fill", .green),
    "com.clone.password": ("lock.fill", .purple),
    "com.clone.fontbook": ("textformat", .purple),
]

let pinnedAppIds: Set<String> = Set(pinnedItems.map(\.appId))

// MARK: - Constants

let baseIconSize: CGFloat = 48
let maxScale: CGFloat = 1.8
let influenceRadius: CGFloat = 120
let iconPadding: CGFloat = 8
let dockHeight: CGFloat = 64
let separatorWidth: CGFloat = 2
let separatorPadding: CGFloat = 6

// MARK: - State

struct MinimizedWindow: Identifiable {
    let windowId: UInt64
    let appId: String
    let title: String
    var thumbnail: Image?
    var id: UInt64 { windowId }
}

final class DockState: ObservableObject {
    @Published var minimizedWindows: [MinimizedWindow] = []
    @Published var runningAppIds: Set<String> = []
    @Published var unpinnedRunningItems: [DockItem] = []
    @Published var hoveredAppId: String?
    @Published var mouseX: CGFloat = 0
    @Published var dockHovered: Bool = false
    /// Window IDs we've already requested thumbnails for.
    var requestedThumbnails: Set<UInt64> = []
}

// MARK: - Magnification

func magnifiedSize(index: Int, mouseX: CGFloat, totalCount: Int, startX: CGFloat) -> CGFloat {
    let iconCenterX = startX + CGFloat(index) * (baseIconSize + iconPadding) + baseIconSize / 2
    let distance = abs(mouseX - iconCenterX)
    if distance > influenceRadius { return baseIconSize }
    let t = 1.0 - (distance / influenceRadius)
    let scale = 1.0 + (maxScale - 1.0) * (1.0 - cos(t * .pi)) / 2.0
    return baseIconSize * scale
}

// MARK: - Dock Icon

struct DockIconView: View {
    @ObservedObject var state: DockState
    let item: DockItem
    let size: CGFloat
    let showRunningDot: Bool

    var body: some View {
        let cornerRadius = size * 0.22
        let isHovered = state.hoveredAppId == item.appId

        VStack(spacing: 4) {
            ZStack {
                // Reserve label height always — prevents layout shift on hover
                Color.clear.frame(width: 1, height: 26)
                if isHovered {
                    let textWidth = CGFloat(item.name.count) * 8 + 20
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.adaptive(dark: Color(red: 0.15, green: 0.15, blue: 0.16, opacity: 0.95),
                                                light: Color(red: 0.98, green: 0.98, blue: 0.98, opacity: 0.95)))
                            .frame(width: textWidth, height: 26)
                        Text(item.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
            .frame(height: 26)
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(item.color)
                    .frame(width: size, height: size)
                Image(systemName: item.icon)
                    .font(.system(size: size * 0.5))
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
                .onHover { hovered in
                    state.hoveredAppId = hovered ? item.appId : nil
                }
                .onTapGesture {
                    #if canImport(CloneClient)
                    SystemActions.shared.launchApp(item.appId)
                    #endif
                }
            if showRunningDot {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.8, green: 0.8, blue: 0.8, opacity: 0.9))
                    .frame(width: 4, height: 4)
            }
        }
    }
}

// MARK: - Minimized Window Thumbnail

struct MinimizedThumbnailView: View {
    @ObservedObject var state: DockState
    let window: MinimizedWindow
    let size: CGFloat

    var body: some View {
        let hoverId = "\(window.windowId).minimized"
        let isHovered = state.hoveredAppId == hoverId
        let thumbW = size
        let thumbH = size

        VStack(spacing: 4) {
            ZStack {
                Color.clear.frame(width: 1, height: 26)
                if isHovered {
                    let textWidth = CGFloat(window.title.count) * 8 + 20
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.adaptive(dark: Color(red: 0.15, green: 0.15, blue: 0.16, opacity: 0.95),
                                                light: Color(red: 0.98, green: 0.98, blue: 0.98, opacity: 0.95)))
                            .frame(width: textWidth, height: 26)
                        Text(window.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
            .frame(height: 26)
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.2, green: 0.2, blue: 0.2, opacity: 0.6))
                    .frame(width: thumbW, height: thumbH)
                if let thumbnail = window.thumbnail {
                    thumbnail
                        .frame(width: thumbW - 4, height: thumbH - 4)
                } else {
                    Image(systemName: "macwindow")
                        .font(.system(size: size * 0.3))
                        .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7, opacity: 1.0))
                }
            }
            .frame(width: thumbW, height: thumbH)
                .onHover { hovered in
                    state.hoveredAppId = hovered ? hoverId : nil
                }
                .onTapGesture {
                    #if canImport(CloneClient)
                    SystemActions.shared.restoreWindow(window.windowId)
                    #endif
                }
        }
    }
}

// MARK: - Separator

struct DockSeparator: View {
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color(red: 0.5, green: 0.5, blue: 0.5, opacity: 0.4))
            .frame(width: separatorWidth, height: height)
            .padding(.horizontal, separatorPadding)
    }
}

// MARK: - Dock View

struct DockView: View {
    @ObservedObject var state: DockState
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        // Collect all items across zones for magnification
        let allItems = pinnedItems + state.unpinnedRunningItems
        let totalCount = allItems.count
        let totalBaseWidth = CGFloat(totalCount) * baseIconSize + CGFloat(max(totalCount - 1, 0)) * iconPadding
        let startX = (width - totalBaseWidth) / 2

        let sizes: [CGFloat] = (0..<totalCount).map { i in
            state.dockHovered ? magnifiedSize(index: i, mouseX: state.mouseX, totalCount: totalCount, startX: startX) : baseIconSize
        }

        // Zone sizes
        let pinnedCount = pinnedItems.count
        let unpinnedCount = state.unpinnedRunningItems.count
        let minimizedCount = state.minimizedWindows.count
        let hasSeparator1 = unpinnedCount > 0 || minimizedCount > 0
        let hasSeparator2 = unpinnedCount > 0 && minimizedCount > 0

        // Total dock width
        let iconWidth = sizes.reduce(0, +) + CGFloat(max(totalCount - 1, 0)) * iconPadding
        let minimizedWidth = minimizedCount > 0 ? CGFloat(minimizedCount) * (baseIconSize + iconPadding) : 0
        let trashWidth = baseIconSize + iconPadding
        let separatorSpace = (hasSeparator1 ? separatorWidth + separatorPadding * 2 : 0)
            + (hasSeparator2 ? separatorWidth + separatorPadding * 2 : 0)
            + (minimizedCount > 0 ? separatorWidth + separatorPadding * 2 : 0) // before trash
        let totalWidth = iconWidth + minimizedWidth + trashWidth + separatorSpace + iconPadding * 2
        let bgHeight = dockHeight + iconPadding * 2

        let maxItemCount = totalCount + minimizedCount + 1 // +1 for trash
        let maxMagnifiedWidth = CGFloat(maxItemCount) * baseIconSize * maxScale + CGFloat(max(maxItemCount - 1, 0)) * iconPadding + iconPadding * 2 + separatorSpace
        let maxMagnifiedHeight = baseIconSize * maxScale + 34 + iconPadding * 2

        VStack(spacing: 0) {
            Spacer()
            ZStack(alignment: .bottom) {
                // Invisible stable hit-test zone
                Color.clear
                    .frame(width: maxMagnifiedWidth, height: maxMagnifiedHeight)
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
                // Visible pill
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.adaptive(dark: Color(red: 0.2, green: 0.2, blue: 0.2, opacity: 0.6),
                                        light: Color(red: 0.95, green: 0.95, blue: 0.95, opacity: 0.7)))
                    .frame(width: totalWidth, height: bgHeight)
                // Icons
                HStack(alignment: .bottom, spacing: iconPadding) {
                    // Zone 1: Pinned apps
                    ForEach(Array(pinnedItems.enumerated()), id: \.offset) { i, item in
                        DockIconView(
                            state: state, item: item, size: sizes[i],
                            showRunningDot: state.runningAppIds.contains(item.appId)
                        )
                    }
                    // Separator between pinned and unpinned running
                    if hasSeparator1 {
                        DockSeparator(height: dockHeight * 0.5)
                    }
                    // Zone 2: Running but unpinned apps
                    ForEach(Array(state.unpinnedRunningItems.enumerated()), id: \.offset) { i, item in
                        DockIconView(
                            state: state, item: item, size: sizes[pinnedCount + i],
                            showRunningDot: true
                        )
                    }
                    // Separator before minimized
                    if hasSeparator2 {
                        DockSeparator(height: dockHeight * 0.5)
                    }
                    // Zone 3: Minimized windows
                    ForEach(Array(state.minimizedWindows.enumerated()), id: \.offset) { _, window in
                        MinimizedThumbnailView(
                            state: state, window: window, size: baseIconSize
                        )
                    }
                    // Separator before trash
                    if minimizedCount > 0 || unpinnedCount > 0 {
                        DockSeparator(height: dockHeight * 0.5)
                    }
                    // Zone 4: Trash
                    VStack(spacing: 4) {
                        ZStack {
                            RoundedRectangle(cornerRadius: baseIconSize * 0.22)
                                .fill(Color(red: 0.4, green: 0.4, blue: 0.42, opacity: 1.0))
                                .frame(width: baseIconSize, height: baseIconSize)
                            Image(systemName: "trash.fill")
                                .font(.system(size: baseIconSize * 0.5))
                                .foregroundColor(.white)
                        }
                        .frame(width: baseIconSize, height: baseIconSize)
                    }
                }
                .padding(.bottom, iconPadding)
            }
            .frame(width: maxMagnifiedWidth, height: maxMagnifiedHeight)
        }
        .frame(width: width, height: height)
    }
}

// MARK: - App Entry Point

@main
struct DockApp: App {
    @StateObject var state = DockState()

    var body: some Scene {
        WindowGroup("Dock") {
            DockView(state: state, width: 1280, height: 800)
        }
    }

    #if canImport(CloneClient)
    var configuration: WindowConfiguration {
        WindowConfiguration(title: "Dock", width: 1280, height: 800, role: .dock)
    }

    func onMinimizedWindows(windows: [MinimizedWindowInfo]) {
        logErr("[Dock] onMinimizedWindows: \(windows.count) windows\n")
        // Preserve existing thumbnails for windows that are still minimized
        let thumbEntries = state.minimizedWindows.compactMap { w in
            w.thumbnail.map { (w.windowId, $0) }
        }
        let existingThumbnails = Dictionary(uniqueKeysWithValues: thumbEntries)
        logErr("[Dock] Preserving \(existingThumbnails.count) thumbnails: \(existingThumbnails.keys.sorted())\n")
        let currentIds = Set(windows.map(\.windowId))
        state.requestedThumbnails = state.requestedThumbnails.intersection(currentIds)
        state.minimizedWindows = windows.map { info in
            MinimizedWindow(
                windowId: info.windowId,
                appId: info.appId,
                title: info.title,
                thumbnail: existingThumbnails[info.windowId]
            )
        }
        logErr("[Dock] State updated, requesting thumbnails...\n")
        // Request thumbnails for new windows we haven't requested yet
        for info in windows where !state.requestedThumbnails.contains(info.windowId) {
            state.requestedThumbnails.insert(info.windowId)
            logErr("[Dock] Sending requestThumbnail for window \(info.windowId)\n")
            client.send(.requestThumbnail(windowId: info.windowId, maxWidth: 48, maxHeight: 36))
            logErr("[Dock] requestThumbnail sent for window \(info.windowId)\n")
        }
        logErr("[Dock] onMinimizedWindows done\n")
    }

    func onWindowThumbnail(windowId: UInt64, pngData: Data) {
        logErr("[Dock] onWindowThumbnail: window=\(windowId) \(pngData.count) bytes PNG\n")
        guard let decoded = try? decodeImage(data: pngData) else {
            logErr("[Dock] Failed to decode PNG\n")
            return
        }
        let image = Image._fromDecodedRGBA(
            textureId: UInt64(windowId &+ 0x1000_0000),
            width: decoded.width,
            height: decoded.height,
            rgbaData: [UInt8](decoded.rgbaData)
        )
        if let idx = state.minimizedWindows.firstIndex(where: { $0.windowId == windowId }) {
            state.minimizedWindows[idx].thumbnail = image
            logErr("[Dock] Thumbnail stored for window \(windowId)\n")
        }
    }

    func onRunningApps(apps: [RunningAppInfo]) {
        let ids = Set(apps.map(\.appId))
        state.runningAppIds = ids
        state.unpinnedRunningItems = apps
            .filter { !pinnedAppIds.contains($0.appId) }
            .map { info in
                let catalog = appCatalog[info.appId]
                return DockItem(
                    appId: info.appId,
                    name: info.title,
                    icon: catalog?.icon ?? "app.fill",
                    color: catalog?.color ?? .gray
                )
            }
    }
    #endif
}
