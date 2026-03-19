import Foundation
import CloneClient
import CloneProtocol

// MARK: - Rose Pine colors

let base     = IPCColor(r: 0.14, g: 0.13, b: 0.19, a: 1)
let surface  = IPCColor(r: 0.18, g: 0.16, b: 0.24, a: 1)
let overlay  = IPCColor(r: 0.22, g: 0.20, b: 0.28, a: 1)
let text     = IPCColor(r: 0.88, g: 0.85, b: 0.91, a: 1)
let subtle   = IPCColor(r: 0.58, g: 0.55, b: 0.63, a: 1)
let muted    = IPCColor(r: 0.42, g: 0.39, b: 0.47, a: 1)

let blue     = IPCColor(r: 0.19, g: 0.55, b: 0.91, a: 1)
let red      = IPCColor(r: 0.92, g: 0.29, b: 0.35, a: 1)
let green    = IPCColor(r: 0.18, g: 0.75, b: 0.49, a: 1)
let purple   = IPCColor(r: 0.58, g: 0.39, b: 0.87, a: 1)
let teal     = IPCColor(r: 0.24, g: 0.70, b: 0.70, a: 1)
let black    = IPCColor(r: 0.0,  g: 0.0,  b: 0.0,  a: 1)
let selected = IPCColor(r: 0.19, g: 0.55, b: 0.91, a: 0.3)

// MARK: - Data model

struct SettingsCategory {
    let name: String
    let color: IPCColor
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
        SettingsCategory(name: "Wi-Fi", color: blue),
        SettingsCategory(name: "Bluetooth", color: blue),
        SettingsCategory(name: "Network", color: blue),
    ]),
    SettingsSection(categories: [
        SettingsCategory(name: "Notifications", color: red),
        SettingsCategory(name: "Sound", color: red),
        SettingsCategory(name: "Focus", color: purple),
    ]),
    SettingsSection(categories: [
        SettingsCategory(name: "General", color: muted),
        SettingsCategory(name: "Appearance", color: blue),
        SettingsCategory(name: "Desktop & Dock", color: black),
        SettingsCategory(name: "Displays", color: blue),
        SettingsCategory(name: "Wallpaper", color: teal),
    ]),
    SettingsSection(categories: [
        SettingsCategory(name: "Privacy & Security", color: blue),
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

    func render(width: Float, height: Float) -> [IPCRenderCommand] {
        var commands: [IPCRenderCommand] = []

        // Sidebar background
        commands.append(.rect(x: 0, y: 0, w: sidebarWidth, h: height, color: base))

        // Detail background
        commands.append(.rect(x: sidebarWidth, y: 0, w: width - sidebarWidth, h: height, color: surface))

        // Sidebar separator
        commands.append(.rect(x: sidebarWidth, y: 0, w: 1, h: height, color: overlay))

        renderSidebar(&commands, height: height)
        renderDetail(&commands, width: width, height: height)

        return commands
    }

    // MARK: - Sidebar rendering

    func renderSidebar(_ commands: inout [IPCRenderCommand], height: Float) {
        var y: Float = 8

        // Profile card
        commands.append(.roundedRect(x: 20, y: y + 6, w: 32, h: 32, radius: 16, color: muted))
        commands.append(.text(x: 60, y: y + 8, content: "manz", fontSize: 13,
                              color: text, weight: .bold))
        commands.append(.text(x: 60, y: y + 24, content: "Apple Account", fontSize: 11,
                              color: subtle, weight: .regular))
        y += profileHeight

        // Divider
        commands.append(.rect(x: 16, y: y, w: sidebarWidth - 32, h: dividerHeight, color: overlay))
        y += sectionGap

        // Category sections
        for (sectionIdx, section) in sections.enumerated() {
            for cat in section.categories {
                let isSelected = cat.name == selectedCategory
                let isHovered = mouseX < sidebarWidth && mouseY >= y && mouseY < y + rowHeight

                // Selection / hover background
                if isSelected {
                    commands.append(.roundedRect(x: 8, y: y, w: sidebarWidth - 16, h: rowHeight,
                                                  radius: 6, color: selected))
                } else if isHovered {
                    commands.append(.roundedRect(x: 8, y: y, w: sidebarWidth - 16, h: rowHeight,
                                                  radius: 6,
                                                  color: IPCColor(r: 0.22, g: 0.20, b: 0.28, a: 0.3)))
                }

                // Icon
                commands.append(.roundedRect(x: 16, y: y + 4, w: 20, h: 20, radius: 5, color: cat.color))

                // Label
                commands.append(.text(x: 44, y: y + 6, content: cat.name, fontSize: 13,
                                      color: isSelected ? IPCColor(r: 1, g: 1, b: 1, a: 1) : text,
                                      weight: .regular))

                y += rowHeight
            }

            // Section divider
            if sectionIdx < sections.count - 1 {
                y += 4
                commands.append(.rect(x: 16, y: y, w: sidebarWidth - 32, h: dividerHeight, color: overlay))
                y += sectionGap - 4
            }
        }
    }

    // MARK: - Detail rendering

    func renderDetail(_ commands: inout [IPCRenderCommand], width: Float, height: Float) {
        let detailX = sidebarWidth + 24
        let detailWidth = width - sidebarWidth - 48
        var y: Float = 16

        // Title
        commands.append(.text(x: detailX, y: y, content: selectedCategory, fontSize: 20,
                              color: text, weight: .bold))
        y += 36

        // Setting groups
        guard let groups = paneData[selectedCategory] else {
            commands.append(.text(x: detailX, y: y, content: "Settings for \(selectedCategory) will appear here.",
                                  fontSize: 13, color: subtle, weight: .regular))
            return
        }

        for group in groups {
            // Section header
            if let header = group.0 {
                commands.append(.text(x: detailX, y: y, content: header, fontSize: 12,
                                      color: subtle, weight: .semibold))
                y += 20
            }

            // Group background
            let groupHeight = Float(group.1.count) * 32 + 4
            commands.append(.roundedRect(x: detailX - 2, y: y, w: detailWidth + 4, h: groupHeight,
                                          radius: 10, color: overlay))

            // Rows
            for (i, row) in group.1.enumerated() {
                let rowY = y + 2 + Float(i) * 32

                // Row hover
                let isHovered = mouseX > sidebarWidth && mouseY >= rowY && mouseY < rowY + 32
                if isHovered {
                    commands.append(.roundedRect(x: detailX, y: rowY, w: detailWidth, h: 32,
                                                  radius: 6,
                                                  color: IPCColor(r: 0.26, g: 0.24, b: 0.32, a: 1)))
                }

                commands.append(.text(x: detailX + 12, y: rowY + 8, content: row.label, fontSize: 13,
                                      color: text, weight: .regular))
                if !row.value.isEmpty {
                    // Right-align the value (approximate)
                    let valueWidth = Float(row.value.count) * 7.8
                    commands.append(.text(x: detailX + detailWidth - valueWidth - 12, y: rowY + 8,
                                          content: row.value, fontSize: 13,
                                          color: subtle, weight: .regular))
                }

                // Row divider
                if i < group.1.count - 1 {
                    commands.append(.rect(x: detailX + 12, y: rowY + 31, w: detailWidth - 24,
                                          h: 1, color: IPCColor(r: 0.26, g: 0.24, b: 0.32, a: 0.5)))
                }
            }

            y += groupHeight + 16
        }
    }

    // MARK: - Interaction

    func handleClick(x: Float, y: Float) {
        guard x < sidebarWidth else { return }

        var hitY: Float = 8 + profileHeight + sectionGap

        for (sectionIdx, section) in sections.enumerated() {
            for cat in section.categories {
                if y >= hitY && y < hitY + rowHeight {
                    selectedCategory = cat.name
                    return
                }
                hitY += rowHeight
            }
            if sectionIdx < sections.count - 1 {
                hitY += sectionGap
            }
        }
    }
}

// MARK: - Main

let client = AppClient()
let state = SettingsState()

do {
    try client.connect(appId: "com.clone.settings", title: "System Settings", width: 700, height: 500)
} catch {
    fputs("Failed to connect to compositor: \(error)\n", stderr)
    exit(1)
}

client.onFrameRequest = { width, height in
    state.render(width: width, height: height)
}

client.onPointerMove = { x, y in
    state.mouseX = x
    state.mouseY = y
}

client.onPointerButton = { button, pressed, x, y in
    if button == 0 && pressed {
        state.handleClick(x: x, y: y)
    }
}

fputs("Settings connected to compositor\n", stderr)
client.runLoop()
fputs("Settings disconnected\n", stderr)
