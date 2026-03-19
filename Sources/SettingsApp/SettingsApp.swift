import SwiftUI

// MARK: - Semantic color aliases

var rpBase: Color { WindowChrome.base }
var rpSurface: Color { WindowChrome.surface }
var rpOverlay: Color { WindowChrome.overlay }
var rpText: Color { .primary }
var rpSubtle: Color { .secondary }
var rpMuted: Color { .gray }

let rpBlue: Color = .blue
let rpRed: Color = .red
let rpGreen: Color = .green
let rpPurple: Color = .purple
let rpTeal: Color = .teal
let rpBlack: Color = .black
var rpSelected: Color { WindowChrome.selection }
var hoverBg: Color { WindowChrome.highlight }
var rowHoverBg: Color { WindowChrome.overlay }
var rowDivider: Color { WindowChrome.separator }

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
    var mouseX: Float = 0
    var mouseY: Float = 0

    let sidebarWidth: Float = 220
    let profileHeight: Float = 50
    let rowHeight: Float = 28
    let sectionGap: Float = 16
    let dividerHeight: Float = 1
}

// MARK: - Sidebar category row Y-position computation

/// Computes the Y offset for a given category index, accounting for section gaps.
/// Returns the Y position where that category row starts in the sidebar.
private func categoryYOffset(state: SettingsState, flatIndex: Int) -> Float {
    var y: Float = 8 + state.profileHeight + state.sectionGap
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

private func profileCard() -> ViewNode {
    HStack(spacing: 8) {
        RoundedRectangle(cornerRadius: 16)
            .fill(rpMuted)
            .frame(width: 32, height: 32)
        VStack(alignment: .leading, spacing: 2) {
            Text("manz").bold().fontSize(13)
            Text("Apple Account").fontSize(11).foregroundColor(rpSubtle)
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
) -> ViewNode {
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
        Text(category.name).fontSize(13).foregroundColor(textColor)
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

private func sidebarView(state: SettingsState, height: Float) -> ViewNode {
    var children: [ViewNode] = [
        profileCard(),
        Rectangle().fill(rpOverlay).frame(height: 1).padding(.horizontal, 16),
    ]
    var flatIndex = 0
    for (sectionIdx, section) in sections.enumerated() {
        for cat in section.categories {
            children.append(categoryRow(state: state, category: cat, flatIndex: flatIndex))
            flatIndex += 1
        }
        if sectionIdx < sections.count - 1 {
            children.append(
                Rectangle().fill(rpOverlay).frame(height: 1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            )
        }
    }
    children.append(Spacer())

    let sidebarContent: ViewNode = .vstack(alignment: .leading, spacing: 0, children: children)
    return ZStack {
        Rectangle().fill(rpBase).frame(width: 220, height: height)
        sidebarContent
    }.frame(width: 220, height: height)
}

// MARK: - Detail row

private func settingRowView(
    state: SettingsState,
    row: SettingRow,
    rowY: Float,
    detailWidth: Float
) -> ViewNode {
    let isHovered = state.mouseX > state.sidebarWidth
        && state.mouseY >= rowY
        && state.mouseY < rowY + 32

    let content = HStack(spacing: 0) {
        Text(row.label).fontSize(13).foregroundColor(rpText)
        Spacer()
        if !row.value.isEmpty {
            Text(row.value).fontSize(13).foregroundColor(rpSubtle)
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
    startY: Float,
    detailWidth: Float
) -> ViewNode {
    let headerOffset: Float = header != nil ? 20 : 0

    // Build row nodes with interleaved dividers
    var rowNodes: [ViewNode] = []
    for (i, row) in rows.enumerated() {
        let rowY = startY + headerOffset + 2 + Float(i) * 32
        rowNodes.append(settingRowView(
            state: state,
            row: row,
            rowY: rowY,
            detailWidth: detailWidth
        ))
        if i < rows.count - 1 {
            rowNodes.append(
                Rectangle().fill(rowDivider).frame(height: 1).padding(.horizontal, 12)
            )
        }
    }

    let rowsStack: ViewNode = .vstack(alignment: .leading, spacing: 0, children: rowNodes)
        .padding(.vertical, 2)

    let groupHeight = Float(rows.count) * 32 + 4
    let groupBox = ZStack {
        RoundedRectangle(cornerRadius: 10).fill(rpOverlay).frame(height: groupHeight)
        rowsStack
    }.frame(height: groupHeight)

    var children: [ViewNode] = []
    if let header = header {
        children.append(
            Text(header).fontSize(12).foregroundColor(rpSubtle).fontWeight(.semibold)
                .padding(.bottom, 4)
        )
    }
    children.append(groupBox)

    return .vstack(alignment: .leading, spacing: 0, children: children)
}

// MARK: - Detail view

private func detailView(state: SettingsState, width: Float) -> ViewNode {
    let groups = paneData[state.selectedCategory]
    let detailWidth = width - 48

    var children: [ViewNode] = [
        Text(state.selectedCategory)
            .bold()
            .fontSize(20)
            .foregroundColor(rpText)
            .padding(.bottom, 12)
    ]

    if let groups = groups {
        // Precompute Y positions for hover detection
        var runningY: Float = 16 + 32  // title area offset
        for (groupIdx, group) in groups.enumerated() {
            let headerOffset: Float = group.0 != nil ? 20 : 0
            let groupStartY = runningY

            children.append(settingGroupView(
                state: state,
                header: group.0,
                rows: group.1,
                startY: groupStartY,
                detailWidth: detailWidth
            ))

            let groupHeight = headerOffset + Float(group.1.count) * 32 + 4
            runningY += groupHeight + 16 + (group.0 != nil ? 4 : 0)

            if groupIdx < groups.count - 1 {
                children.append(Spacer(minLength: 16))
            }
        }
    } else {
        children.append(
            Text("Settings for \(state.selectedCategory) will appear here.")
                .fontSize(13)
                .foregroundColor(rpSubtle)
        )
    }

    children.append(Spacer())

    let content: ViewNode = .vstack(alignment: .leading, spacing: 0, children: children)
        .padding(24)
    return ZStack {
        Rectangle().fill(rpSurface).frame(width: width)
        content
    }.frame(width: width)
}

// MARK: - Root settings view

func settingsView(state: SettingsState, width: Float, height: Float) -> ViewNode {
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

    func onPointerMove(x: Float, y: Float) {
        state.mouseX = x
        state.mouseY = y
    }
}
