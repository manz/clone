import Foundation
import AppKit

// MARK: - Open panel overlay — rendered by the app when NSSavePanel._activePanel is set

private let panelW: CGFloat = 480
private let panelH: CGFloat = 400
private let titleBarH: CGFloat = 40
private let pathBarH: CGFloat = 28
private let footerH: CGFloat = 48
private let rowH: CGFloat = 24
private let buttonH: CGFloat = 30
private let buttonW: CGFloat = 80
private let contentH: CGFloat = panelH - titleBarH - pathBarH - footerH - 2 // 2 for borders

private let panelBg = Color(red: 0.98, green: 0.98, blue: 0.98)
private let panelTitleBg = Color(red: 0.93, green: 0.93, blue: 0.93)
private let panelContentBg = Color(red: 1, green: 1, blue: 1)
private let panelBorder = Color(red: 0, green: 0, blue: 0, opacity: 0.1)
private let panelSelected = Color(red: 0.04, green: 0.52, blue: 1.0)
private let panelHover = Color(red: 0, green: 0, blue: 0, opacity: 0.04)
private let panelButtonBg = Color(red: 0.2, green: 0.47, blue: 0.96)
private let panelCancelBg = Color(red: 0.85, green: 0.85, blue: 0.85)

// MARK: - Build panel ViewNode

/// Builds the file dialog as a ViewNode tree. Called from the app render loop
/// when `NSSavePanel._activePanel` is set.
@MainActor
public func buildOpenPanelOverlay(width: CGFloat, height: CGFloat) -> ViewNode? {
    guard let panel = NSSavePanel._activePanel else { return nil }
    let state = panel.panelState

    let ox = (width - panelW) / 2
    let oy = (height - panelH) / 2

    // Dim background
    let dimBg: ViewNode = .rect(width: width, height: height, fill: Color(red: 0, green: 0, blue: 0, opacity: 0.3))

    // Title bar
    let titleBar: ViewNode = .zstack(children: [
        .rect(width: panelW, height: titleBarH, fill: panelTitleBg),
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 0, trailing: 0),
                 child: .text("Open", fontSize: 14, color: .primary, weight: .semibold))
    ])

    // Path bar
    let pathDisplay = shortenPath(state.currentPath)
    let pathBar: ViewNode = .zstack(children: [
        .rect(width: panelW, height: pathBarH, fill: panelTitleBg),
        .padding(EdgeInsets(top: 6, leading: 12, bottom: 0, trailing: 0),
                 child: .text(pathDisplay, fontSize: 12, color: .secondary))
    ])

    // File rows
    let visibleRows = Int(contentH / rowH)
    let scrollOffset = max(0, state.selectedIndex - visibleRows + 3)
    var rows: [ViewNode] = []

    for i in 0..<state.entries.count {
        let displayIdx = i - scrollOffset
        if displayIdx < 0 || displayIdx >= visibleRows + 1 { continue }

        let entry = state.entries[i]
        let isSelected = i == state.selectedIndex
        let entryLocalY = titleBarH + pathBarH + 1 + CGFloat(displayIdx) * rowH
        let isHovered = !isSelected
            && state.mouseX >= ox && state.mouseX < ox + panelW
            && state.mouseY >= oy + entryLocalY && state.mouseY < oy + entryLocalY + rowH

        let prefix = entry.isDirectory ? "▸ " : "  "
        let textColor: Color = isSelected ? .white : .primary
        let bg: Color = isSelected ? panelSelected : (isHovered ? panelHover : .clear)

        rows.append(.frame(width: panelW, height: rowH, child:
            .zstack(children: [
                .rect(width: panelW - 8, height: rowH, fill: bg),
                .padding(EdgeInsets(top: 4, leading: 12, bottom: 0, trailing: 0),
                         child: .text(prefix + entry.name, fontSize: 13, color: textColor,
                                      weight: entry.isDirectory ? .medium : .regular))
            ])
        ))
    }
    if rows.isEmpty {
        rows.append(.padding(EdgeInsets(top: 20, leading: 16, bottom: 0, trailing: 0),
                             child: .text("Empty folder", fontSize: 13, color: .secondary)))
    }

    let fileList: ViewNode = .zstack(children: [
        .rect(width: panelW, height: contentH, fill: panelContentBg),
        .vstack(alignment: .leading, spacing: 0, children: rows)
    ])

    // Footer buttons
    let cancelBtn: ViewNode = .zstack(children: [
        .roundedRect(width: buttonW, height: buttonH, radius: 6, fill: panelCancelBg),
        .text("Cancel", fontSize: 13, color: .primary)
    ])
    let openBtn: ViewNode = .zstack(children: [
        .roundedRect(width: buttonW, height: buttonH, radius: 6, fill: panelButtonBg),
        .text("Open", fontSize: 13, color: .white, weight: .medium)
    ])
    let footer: ViewNode = .zstack(children: [
        .rect(width: panelW, height: footerH, fill: panelBg),
        .hstack(alignment: .center, spacing: 12, children: [
            .spacer(minLength: 0),
            cancelBtn,
            openBtn,
            .spacer(minLength: 12),
        ])
    ])

    // Dialog body
    let dialogBody: ViewNode = .vstack(alignment: .leading, spacing: 0, children: [
        titleBar,
        pathBar,
        .rect(width: panelW, height: 1, fill: panelBorder),
        fileList,
        .rect(width: panelW, height: 1, fill: panelBorder),
        footer,
    ])

    // Dialog with background + shadow
    let dialog: ViewNode = .shadow(radius: 12, blur: 20, color: Color(red: 0, green: 0, blue: 0, opacity: 0.25), offsetX: 0, offsetY: 4, child:
        .zstack(children: [
            .roundedRect(width: panelW, height: panelH, radius: 12, fill: panelBg),
            dialogBody,
        ])
    )

    // Position dialog centered — use padding from top-left
    let positioned: ViewNode = .padding(
        EdgeInsets(top: oy, leading: ox, bottom: 0, trailing: 0),
        child: dialog
    )

    return .zstack(children: [dimBg, positioned])
}

// MARK: - Input handling

/// Handle a click on the panel. Returns true if the panel consumed the event.
@MainActor
public func handleOpenPanelClick(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> Bool {
    guard let panel = NSSavePanel._activePanel else { return false }
    let state = panel.panelState
    let ox = (width - panelW) / 2
    let oy = (height - panelH) / 2
    let lx = x - ox
    let ly = y - oy

    // Outside dialog → cancel
    if lx < 0 || lx > panelW || ly < 0 || ly > panelH {
        panel.cancel()
        return true
    }

    // Footer buttons
    let footerY = panelH - footerH
    if ly >= footerY {
        let btnY = footerY + (footerH - buttonH) / 2
        if ly >= btnY && ly < btnY + buttonH {
            // Cancel: left button
            let cancelX = panelW - buttonW * 2 - 24
            if lx >= cancelX && lx < cancelX + buttonW {
                panel.cancel()
                return true
            }
            // Open: right button
            let openX = panelW - buttonW - 12
            if lx >= openX && lx < openX + buttonW {
                guard state.selectedIndex < state.entries.count else { return true }
                let entry = state.entries[state.selectedIndex]
                if entry.isDirectory {
                    state.currentPath = entry.path
                    state.loadDirectory()
                } else {
                    panel.resolve(path: entry.path)
                }
                return true
            }
        }
        return true
    }

    // File list
    let contentTop = titleBarH + pathBarH + 1
    if ly >= contentTop && ly < contentTop + contentH {
        let visibleRows = Int(contentH / rowH)
        let scrollOffset = max(0, state.selectedIndex - visibleRows + 3)
        let clickedRow = Int((ly - contentTop) / rowH) + scrollOffset
        if clickedRow >= 0 && clickedRow < state.entries.count {
            if state.selectedIndex == clickedRow {
                let entry = state.entries[clickedRow]
                if entry.isDirectory {
                    state.currentPath = entry.path
                    state.loadDirectory()
                } else {
                    panel.resolve(path: entry.path)
                }
            } else {
                state.selectedIndex = clickedRow
            }
        }
        return true
    }

    return true
}

/// Handle a key press on the panel. Returns true if consumed.
@MainActor
public func handleOpenPanelKey(keycode: UInt32) -> Bool {
    guard let panel = NSSavePanel._activePanel else { return false }
    let state = panel.panelState

    switch keycode {
    case 82: // Up
        if state.selectedIndex > 0 { state.selectedIndex -= 1 }
    case 81: // Down
        if state.selectedIndex < state.entries.count - 1 { state.selectedIndex += 1 }
    case 40: // Enter
        guard state.selectedIndex < state.entries.count else { return true }
        let entry = state.entries[state.selectedIndex]
        if entry.isDirectory {
            state.currentPath = entry.path
            state.loadDirectory()
        } else {
            panel.resolve(path: entry.path)
        }
    case 41: // Escape
        panel.cancel()
    default:
        return false
    }
    return true
}

/// Update mouse position for hover tracking.
@MainActor
public func updateOpenPanelMouse(x: CGFloat, y: CGFloat) {
    guard let panel = NSSavePanel._activePanel else { return }
    panel.panelState.mouseX = x
    panel.panelState.mouseY = y
}

// MARK: - Helpers

private func shortenPath(_ path: String) -> String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    if path.hasPrefix(home) {
        return "~" + path.dropFirst(home.count)
    }
    return path
}
