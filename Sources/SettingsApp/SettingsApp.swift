import Foundation
import SwiftUI

// MARK: - Semantic color aliases

#if canImport(AppKit) && !canImport(CloneClient)
import AppKit
var rpBase: Color { Color(nsColor: .windowBackgroundColor) }
var rpSurface: Color { Color(nsColor: .controlBackgroundColor) }
var rpOverlay: Color { Color(nsColor: .unemphasizedSelectedContentBackgroundColor) }
var rpSelected: Color { Color.accentColor.opacity(0.3) }
var hoverBg: Color { Color(nsColor: .unemphasizedSelectedContentBackgroundColor).opacity(0.5) }
var rowHoverBg: Color { Color(nsColor: .unemphasizedSelectedContentBackgroundColor) }
var rowDivider: Color { Color(nsColor: .separatorColor) }
#else
let rpBase = Color(red: 0.96, green: 0.96, blue: 0.97)
let rpSurface = Color(red: 1.0, green: 1.0, blue: 1.0)
let rpOverlay = Color(red: 0.93, green: 0.93, blue: 0.94)
let rpSelected = Color(red: 0.04, green: 0.52, blue: 1.0, opacity: 0.2)
let hoverBg = Color(red: 0, green: 0, blue: 0, opacity: 0.04)
let rowHoverBg = Color(red: 0.93, green: 0.93, blue: 0.94)
let rowDivider = Color(red: 0, green: 0, blue: 0, opacity: 0.08)
#endif
var rpText: Color { .primary }
var rpSubtle: Color { .secondary }
var rpMuted: Color { .gray }

let rpBlue: Color = .blue
let rpRed: Color = .red
let rpGreen: Color = .green
let rpPurple: Color = .purple
let rpTeal: Color = .teal
let rpBlack: Color = .black

// MARK: - Data model

struct SettingsCategory {
    let name: String
    let color: Color
    let icon: String
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
        SettingsCategory(name: "Wi-Fi", color: rpBlue, icon: "wifi"),
        SettingsCategory(name: "Bluetooth", color: rpBlue, icon: "network"),
        SettingsCategory(name: "Network", color: rpBlue, icon: "globe"),
    ]),
    SettingsSection(categories: [
        SettingsCategory(name: "Notifications", color: rpRed, icon: "bell.fill"),
        SettingsCategory(name: "Sound", color: rpRed, icon: "speaker.wave.2"),
        SettingsCategory(name: "Focus", color: rpPurple, icon: "moon.fill"),
    ]),
    SettingsSection(categories: [
        SettingsCategory(name: "General", color: rpMuted, icon: "gearshape.fill"),
        SettingsCategory(name: "Appearance", color: rpBlue, icon: "paintbrush"),
        SettingsCategory(name: "Desktop & Dock", color: rpBlack, icon: "desktopcomputer"),
        SettingsCategory(name: "Displays", color: rpBlue, icon: "display"),
        SettingsCategory(name: "Wallpaper", color: rpTeal, icon: "photo.fill"),
    ]),
    SettingsSection(categories: [
        SettingsCategory(name: "Privacy & Security", color: rpBlue, icon: "shield.checkered"),
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

@MainActor private func profileCard() -> some View {
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

@MainActor private func categoryRow(
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
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(category.color)
                .frame(width: 20, height: 20)
                .shadow(color: Color(red: 0, green: 0, blue: 0, opacity: 0.4), radius: 3, x: 0, y: 1)
            Image(systemName: category.icon)
                .foregroundColor(.white)
                .frame(width: 12, height: 12)
        }
        .frame(width: 20, height: 20)
        Text(category.name).font(.system(size: 13)).foregroundColor(textColor)
        Spacer()
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

@MainActor private func sidebarView(state: SettingsState, height: CGFloat) -> some View {
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

@MainActor private func settingRowView(
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

    let bg: Color = isHovered ? rowHoverBg : .clear
    return ZStack {
        RoundedRectangle(cornerRadius: 6).fill(bg).frame(height: 32)
        content
    }.frame(height: 32)
}

// MARK: - Detail group

@MainActor private func settingGroupView(
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

@MainActor private func detailView(state: SettingsState, width: CGFloat) -> some View {
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

@MainActor func settingsView(state: SettingsState, width: CGFloat, height: CGFloat) -> some View {
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
    @State private var selectedCategory: String? = "Appearance"
    @State private var appearanceMode: String = "Light"

    var body: some Scene {
        WindowGroup("System Settings") {
            NavigationSplitView {
                List(selection: $selectedCategory) {
                    Section("") {
                        ForEach(["Appearance", "Desktop & Dock", "Displays", "Wallpaper", "Sound", "Notifications", "Network", "General"], id: \.self) { category in
                            Label(category, systemImage: "gear")
                                .tag(category)
                        }
                    }
                }
                .listStyle(.sidebar)
                .navigationTitle("System Settings")
            } detail: {
                if selectedCategory == "Appearance" {
                    appearanceSettings
                } else if let category = selectedCategory {
                    VStack {
                        Text(category).font(.title).padding()
                        Text("Settings for \(category) coming soon.")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    Text("Select a category")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Appearance").font(.title).padding(.bottom, 4)

            HStack(spacing: 24) {
                ForEach(["Light", "Dark", "Auto"], id: \.self) { mode in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(mode == "Dark" ? Color(white: 0.2) : Color(white: 0.95))
                            .frame(width: 80, height: 56)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(appearanceMode == mode ? Color.accentColor : Color(white: 0.8), lineWidth: appearanceMode == mode ? 2 : 1)
                            )
                        Text(mode)
                            .font(.caption)
                            .foregroundColor(appearanceMode == mode ? .primary : .secondary)
                    }
                    .onTapGesture {
                        appearanceMode = mode
                        applyAppearance(mode)
                    }
                }
            }
            .padding(.leading, 4)

            Divider()

            HStack {
                Text("Accent Color")
                Spacer()
                Text("Blue").foregroundColor(.secondary)
            }

            HStack {
                Text("Sidebar Icon Size")
                Spacer()
                Text("Medium").foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(20)
    }

    private func applyAppearance(_ mode: String) {
        let dark: Bool
        switch mode {
        case "Dark": dark = true
        case "Auto":
            let hour = Calendar.current.component(.hour, from: Date())
            dark = hour >= 18 || hour < 6
        default: dark = false
        }
        SystemActions.shared.setColorScheme(dark: dark)
    }

    #if canImport(CloneClient)
    var configuration: WindowConfiguration {
        WindowConfiguration(title: "System Settings", width: 700, height: 500)
    }
    #endif
}
