import Foundation
import SwiftUI

// MARK: - Semantic color aliases

var rpBase: Color { Color(nsColor: .windowBackgroundColor) }
var rpSurface: Color { Color(nsColor: .controlBackgroundColor) }
var rpOverlay: Color { Color(nsColor: .gridColor) }
var rpText: Color { .primary }
var rpSubtle: Color { .secondary }
var rpMuted: Color { .gray }

let rpBlue: Color = .blue
let rpRed: Color = .red
let rpGreen: Color = .green
let rpPurple: Color = .purple
let rpTeal: Color = .teal
let rpBlack: Color = .black
var rpSelected: Color { Color(nsColor: .selectedControlColor) }
var hoverBg: Color { WindowChrome.highlight }
var rowHoverBg: Color { Color(nsColor: .gridColor) }
var rowDivider: Color { Color(nsColor: .separatorColor) }

// MARK: - Data model

struct SettingsCategory {
    let name: String
    let color: Color
}

struct SettingsSection {
    let categories: [SettingsCategory]
}

struct SettingRow {
    let label: String
    let value: String
}

let sections: [SettingsSection] = [
    SettingsSection(categories: [
        SettingsCategory(name: "Wi-Fi", color: rpBlue),
        SettingsCategory(name: "Bluetooth", color: rpBlue),
        SettingsCategory(name: "Network", color: rpBlue),
    ]),
    SettingsSection(categories: [
        SettingsCategory(name: "Notifications", color: rpRed),
        SettingsCategory(name: "Sound", color: rpRed),
        SettingsCategory(name: "Focus", color: rpPurple),
    ]),
    SettingsSection(categories: [
        SettingsCategory(name: "General", color: rpMuted),
        SettingsCategory(name: "Appearance", color: rpBlue),
        SettingsCategory(name: "Desktop & Dock", color: rpBlack),
        SettingsCategory(name: "Displays", color: rpBlue),
        SettingsCategory(name: "Wallpaper", color: rpTeal),
    ]),
    SettingsSection(categories: [
        SettingsCategory(name: "Privacy & Security", color: rpBlue),
    ]),
]

let allCategories = sections.flatMap(\.categories)

// MARK: - Detail pane data

let paneData: [String: [(String?, [SettingRow])]] = [
    "General": [
        ("About", [
            SettingRow(label: "About", value: "This Mac"),
            SettingRow(label: "Software Update", value: "Up to date"),
            SettingRow(label: "Storage", value: "245 GB available"),
        ]),
        (nil, [
            SettingRow(label: "AirDrop & Handoff", value: ""),
            SettingRow(label: "Login Items", value: ""),
            SettingRow(label: "Language & Region", value: "English"),
            SettingRow(label: "Date & Time", value: "Automatic"),
        ]),
    ],
    "Wi-Fi": [
        (nil, [
            SettingRow(label: "Status", value: "Connected"),
            SettingRow(label: "Network", value: "FreeBox-5G"),
            SettingRow(label: "IP Address", value: "192.168.1.42"),
        ]),
        ("Known Networks", [
            SettingRow(label: "FreeBox-5G", value: "Auto Join"),
            SettingRow(label: "Woosmap-Guest", value: "Auto Join"),
            SettingRow(label: "iPhone de Manz", value: "Auto Join"),
        ]),
    ],
    "Bluetooth": [
        (nil, [
            SettingRow(label: "Bluetooth", value: "On"),
            SettingRow(label: "Discoverable", value: "Off"),
        ]),
        ("My Devices", [
            SettingRow(label: "Magic Keyboard", value: "Connected"),
            SettingRow(label: "AirPods Pro", value: "Not Connected"),
        ]),
    ],
    "Network": [
        (nil, [
            SettingRow(label: "Wi-Fi", value: "Connected"),
            SettingRow(label: "Ethernet", value: "Not Connected"),
            SettingRow(label: "VPN", value: "Not Connected"),
        ]),
    ],
    "Notifications": [
        (nil, [
            SettingRow(label: "Show Previews", value: "When Unlocked"),
            SettingRow(label: "Allow on Lock Screen", value: "On"),
        ]),
        ("Application Notifications", [
            SettingRow(label: "Finder", value: "Banners"),
            SettingRow(label: "Terminal", value: "Off"),
            SettingRow(label: "Mail", value: "Alerts"),
            SettingRow(label: "Calendar", value: "Banners"),
        ]),
    ],
    "Sound": [
        ("Output", [
            SettingRow(label: "Volume", value: "75%"),
            SettingRow(label: "Device", value: "MacBook Pro Speakers"),
        ]),
        ("Input", [
            SettingRow(label: "Device", value: "MacBook Pro Microphone"),
        ]),
        ("Sound Effects", [
            SettingRow(label: "Alert Sound", value: "Boop"),
            SettingRow(label: "Play on startup", value: "On"),
        ]),
    ],
    "Focus": [
        (nil, [
            SettingRow(label: "Do Not Disturb", value: "Off"),
            SettingRow(label: "Share Across Devices", value: "On"),
        ]),
    ],
    "Appearance": [
        (nil, [
            SettingRow(label: "Appearance", value: "Dark"),
            SettingRow(label: "Accent Color", value: "Blue"),
            SettingRow(label: "Highlight Color", value: "Accent Color"),
            SettingRow(label: "Sidebar Icon Size", value: "Medium"),
            SettingRow(label: "Show Scroll Bars", value: "Automatically"),
        ]),
    ],
    "Desktop & Dock": [
        ("Dock", [
            SettingRow(label: "Size", value: "Medium"),
            SettingRow(label: "Magnification", value: "On"),
            SettingRow(label: "Position", value: "Bottom"),
            SettingRow(label: "Minimize Using", value: "Genie Effect"),
            SettingRow(label: "Automatically Hide", value: "Off"),
            SettingRow(label: "Show Recent Apps", value: "On"),
        ]),
    ],
    "Displays": [
        (nil, [
            SettingRow(label: "Resolution", value: "Default for display"),
            SettingRow(label: "Brightness", value: "Auto"),
            SettingRow(label: "True Tone", value: "On"),
            SettingRow(label: "Refresh Rate", value: "ProMotion"),
        ]),
    ],
    "Wallpaper": [
        (nil, [
            SettingRow(label: "Current Wallpaper", value: "Sequoia"),
            SettingRow(label: "Show on All Spaces", value: "On"),
        ]),
    ],
    "Privacy & Security": [
        ("Privacy", [
            SettingRow(label: "Location Services", value: "On"),
            SettingRow(label: "Contacts", value: "3 apps"),
            SettingRow(label: "Calendars", value: "2 apps"),
            SettingRow(label: "Full Disk Access", value: "5 apps"),
        ]),
        ("Security", [
            SettingRow(label: "FileVault", value: "On"),
            SettingRow(label: "Firewall", value: "On"),
        ]),
    ],
]

// MARK: - State

final class SettingsState {
    var selectedCategory: String = "General"
    var mouseX: CGFloat = 0
    var mouseY: CGFloat = 0

    let sidebarWidth: CGFloat = 220
    let profileHeight: CGFloat = 50
    let rowHeight: CGFloat = 28
    let sectionGap: CGFloat = 16
    let dividerHeight: CGFloat = 1
}

// MARK: - Sidebar category row Y-position computation

/// Computes the Y offset for a given category index, accounting for section gaps.
/// Returns the Y position where that category row starts in the sidebar.
private func categoryYOffset(state: SettingsState, flatIndex: Int) -> CGFloat {
    var y: CGFloat = 8 + state.profileHeight + state.sectionGap
    var idx = 0
    for (sectionIdx, section) in sections.enumerated() {
        for _ in section.categories {
            if idx == flatIndex { return y }
            y += state.rowHeight
            idx += 1
        }
        if sectionIdx < sections.count - 1 {
            y += state.sectionGap
        }
    }
    return y
}

// MARK: - Profile card

private func profileCard() -> some View {
    HStack(spacing: 8) {
        RoundedRectangle(cornerRadius: 16)
            .fill(rpMuted)
            .frame(width: 32, height: 32)
        VStack(alignment: .leading, spacing: 2) {
            Text("manz").font(.system(size: 13, weight: .bold))
            Text("Apple Account").font(.system(size: 11)).foregroundColor(rpSubtle)
        }
    }
    .padding(.leading, 12)
    .padding(.vertical, 8)
}

// MARK: - Sidebar category row

private func categoryRow(
    state: SettingsState,
    category: SettingsCategory,
    flatIndex: Int
) -> some View {
    let isSelected = category.name == state.selectedCategory
    let rowY = categoryYOffset(state: state, flatIndex: flatIndex)
    let isHovered = state.mouseX < state.sidebarWidth
        && state.mouseY >= rowY
        && state.mouseY < rowY + state.rowHeight

    let bgColor: Color = isSelected ? rpSelected : (isHovered ? hoverBg : .clear)
    let textColor: Color = isSelected ? .white : rpText

    let content = HStack(spacing: 8) {
        RoundedRectangle(cornerRadius: 5)
            .fill(category.color)
            .frame(width: 20, height: 20)
        Text(category.name).font(.system(size: 13)).foregroundColor(textColor)
    }
    .padding(.horizontal, 8)

    return ZStack {
        RoundedRectangle(cornerRadius: 6).fill(bgColor).frame(height: state.rowHeight)
        content
    }
    .frame(height: state.rowHeight)
    .onTapGesture {
        state.selectedCategory = category.name
    }
}

// MARK: - Sidebar view

/// Pairs each category with its flat index across all sections.
private let indexedSections: [(sectionIdx: Int, categories: [(category: SettingsCategory, flatIndex: Int)])] = {
    var flatIndex = 0
    return sections.enumerated().map { (sectionIdx, section) in
        let cats = section.categories.map { cat -> (SettingsCategory, Int) in
            let idx = flatIndex
            flatIndex += 1
            return (cat, idx)
        }
        return (sectionIdx, cats)
    }
}()

private func sidebarView(state: SettingsState, height: CGFloat) -> some View {
    let sidebarContent = VStack(alignment: .leading, spacing: 0) {
        profileCard()
        Rectangle().fill(rpOverlay).frame(height: 1).padding(.horizontal, 16)
        ForEach(Array(indexedSections.enumerated()), id: \.offset) { _, entry in
            ForEach(Array(entry.categories.enumerated()), id: \.offset) { _, catPair in
                categoryRow(state: state, category: catPair.category, flatIndex: catPair.flatIndex)
            }
            if entry.sectionIdx < sections.count - 1 {
                Rectangle().fill(rpOverlay).frame(height: 1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
        Spacer()
    }
    return ZStack {
        Rectangle().fill(rpBase).frame(width: 220, height: height)
        sidebarContent
    }.frame(width: 220, height: height)
}

// MARK: - Detail row

private func settingRowView(
    state: SettingsState,
    row: SettingRow,
    rowY: CGFloat,
    detailWidth: CGFloat
) -> some View {
    let isHovered = state.mouseX > state.sidebarWidth
        && state.mouseY >= rowY
        && state.mouseY < rowY + 32

    let content = HStack(spacing: 0) {
        Text(row.label).font(.system(size: 13)).foregroundColor(rpText)
        Spacer()
        if !row.value.isEmpty {
            Text(row.value).font(.system(size: 13)).foregroundColor(rpSubtle)
        }
    }
    .padding(.horizontal, 12)

    if isHovered {
        return ZStack {
            RoundedRectangle(cornerRadius: 6).fill(rowHoverBg).frame(height: 32)
            content
        }.frame(height: 32)
    }

    return content.frame(height: 32)
}

// MARK: - Detail group

private func settingGroupView(
    state: SettingsState,
    header: String?,
    rows: [SettingRow],
    startY: CGFloat,
    detailWidth: CGFloat
) -> some View {
    let headerOffset: CGFloat = header != nil ? 20 : 0

    // Build row nodes with interleaved dividers
    let rowsStack = VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
            let rowY = startY + headerOffset + 2 + CGFloat(i) * 32
            settingRowView(
                state: state,
                row: row,
                rowY: rowY,
                detailWidth: detailWidth
            )
            if i < rows.count - 1 {
                Rectangle().fill(rowDivider).frame(height: 1).padding(.horizontal, 12)
            }
        }
    }
    .padding(.vertical, 2)

    let groupHeight = CGFloat(rows.count) * 32 + 4
    let groupBox = ZStack {
        RoundedRectangle(cornerRadius: 10).fill(rpOverlay).frame(height: groupHeight)
        rowsStack
    }.frame(height: groupHeight)

    return VStack(alignment: .leading, spacing: 0) {
        if let header = header {
            Text(header).font(.system(size: 12, weight: .semibold)).foregroundColor(rpSubtle)
                .padding(.bottom, 4)
        }
        groupBox
    }
}

// MARK: - Detail view

/// Pre-computes the startY for each group so the ViewBuilder loop stays mutation-free.
private func groupStartYs(for groups: [(String?, [SettingRow])]) -> [CGFloat] {
    var runningY: CGFloat = 16 + 32  // title area offset
    var result: [CGFloat] = []
    for group in groups {
        result.append(runningY)
        let headerOffset: CGFloat = group.0 != nil ? 20 : 0
        let groupHeight = headerOffset + CGFloat(group.1.count) * 32 + 4
        runningY += groupHeight + 16 + (group.0 != nil ? 4 : 0)
    }
    return result
}

private func detailView(state: SettingsState, width: CGFloat) -> some View {
    let groups = paneData[state.selectedCategory]
    let detailWidth = width - 48
    let startYs = groups.map { groupStartYs(for: $0) } ?? []

    let content = VStack(alignment: .leading, spacing: 0) {
        Text(state.selectedCategory)
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(rpText)
            .padding(.bottom, 12)

        if let groups = groups {
            ForEach(Array(groups.enumerated()), id: \.offset) { groupIdx, group in
                settingGroupView(
                    state: state,
                    header: group.0,
                    rows: group.1,
                    startY: startYs[groupIdx],
                    detailWidth: detailWidth
                )
                if groupIdx < groups.count - 1 {
                    Spacer(minLength: 16)
                }
            }
        } else {
            Text("Settings for \(state.selectedCategory) will appear here.")
                .font(.system(size: 13))
                .foregroundColor(rpSubtle)
        }

        Spacer()
    }
    .padding(24)
    return ZStack {
        Rectangle().fill(rpSurface).frame(width: width)
        content
    }.frame(width: width)
}

// MARK: - Root settings view

func settingsView(state: SettingsState, width: CGFloat, height: CGFloat) -> some View {
    HStack(spacing: 0) {
        sidebarView(state: state, height: height)
            .frame(width: 220)

        // Separator
        Rectangle().fill(rpOverlay).frame(width: 1, height: height)

        // Detail pane
        detailView(state: state, width: width - 221)
    }
}

// MARK: - App

@main
struct SettingsApp: App {
    let state = SettingsState()

    var body: some Scene {
        WindowGroup("System Settings") {
            settingsView(state: state, width: WindowState.shared.width, height: WindowState.shared.height)
        }
    }

    var configuration: WindowConfiguration {
        WindowConfiguration(title: "System Settings", width: 700, height: 500)
    }

    func onPointerMove(x: CGFloat, y: CGFloat) {
        state.mouseX = x
        state.mouseY = y
    }
}
