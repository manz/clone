import Foundation
import AppKit

// MARK: - Open Panel SwiftUI View

/// SwiftUI view for the open/save panel — uses FileBrowserState + FileListView.
/// Rendered as a sheet overlay when NSSavePanel._activePanel is set.
/// Cached browser state for the active panel.
@MainActor private var _panelBrowser: FileBrowserState?

@MainActor
public func buildOpenPanelOverlay(width: CGFloat, height: CGFloat) -> ViewNode? {
    guard let panel = NSSavePanel._activePanel else {
        _panelBrowser = nil
        return nil
    }
    // Create or reuse browser state for this panel
    if _panelBrowser == nil {
        let browser = FileBrowserState(path: panel.startPath)
        browser.allowedExtensions = panel.allowedContentTypes
        _panelBrowser = browser
    }
    let browser = _panelBrowser!

    let panelW: CGFloat = min(600, width - 40)
    let panelH: CGFloat = min(450, height - 40)

    // Build the panel content using shared file browser views
    let sidebar = _resolve(FileBrowserSidebar(state: browser))
    let fileList = _resolve(FileListView(state: browser, onOpen: { entry in
        if entry.isDirectory {
            browser.navigateTo(entry.id)
        }
    }, onSelect: { _ in }))

    // Navigation buttons
    let navButtons = _resolve(FileBrowserNavButtons(state: browser))

    // Path breadcrumb
    let pathLabel = ViewNode.text(browser.shortPath, fontSize: 12, color: .secondary)

    // Toolbar
    let toolbar = ViewNode.hstack(alignment: .center, spacing: 8, children: [
        navButtons,
        .spacer(minLength: 0),
        pathLabel,
        .spacer(minLength: 0),
    ]).padding(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))

    // Split view: sidebar (180px) | file list
    let sidebarColumn = ViewNode.frame(width: 180, height: nil, child: sidebar)
    let divider = ViewNode.rect(width: 1, height: nil, fill: Color(nsColor: .separatorColor))
    let splitView = ViewNode.hstack(alignment: .top, spacing: 0, children: [
        sidebarColumn,
        divider,
        fileList,
    ])

    // Footer with Cancel + Open buttons
    let cancelTapId = TapRegistry.shared.register { panel.cancel() }
    let openTapId = TapRegistry.shared.register {
        if let entry = browser.selectedEntry, !entry.isDirectory {
            panel.resolve(path: entry.id)
        } else if let entry = browser.selectedEntry, entry.isDirectory {
            browser.navigateTo(entry.id)
        }
    }

    let cancelBtn = ViewNode.onTap(id: cancelTapId, child:
        ViewNode.zstack(children: [
            .roundedRect(width: 80, height: 28, radius: 6, fill: Color(nsColor: .controlBackgroundColor)),
            .text("Cancel", fontSize: 13, color: .primary),
        ])
    )
    let openBtn = ViewNode.onTap(id: openTapId, child:
        ViewNode.zstack(children: [
            .roundedRect(width: 80, height: 28, radius: 6, fill: .accentColor),
            .text("Open", fontSize: 13, color: .white, weight: .medium),
        ])
    )
    let footer = ViewNode.hstack(alignment: .center, spacing: 12, children: [
        .spacer(minLength: 0),
        cancelBtn,
        openBtn,
    ]).padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

    let footerDivider = ViewNode.rect(width: nil, height: 1, fill: Color(nsColor: .separatorColor))

    // Assemble panel
    let panelContent = ViewNode.vstack(alignment: .leading, spacing: 0, children: [
        toolbar,
        ViewNode.rect(width: nil, height: 1, fill: Color(nsColor: .separatorColor)),
        splitView,
        footerDivider,
        footer,
    ])

    let panel_node = ViewNode.frame(width: panelW, height: panelH, child: panelContent)
        .background(Color(nsColor: .windowBackgroundColor), cornerRadius: 12)

    // Center in window
    let centered = ViewNode.vstack(alignment: .center, spacing: 0, children: [
        .spacer(minLength: 0),
        ViewNode.hstack(alignment: .center, spacing: 0, children: [
            .spacer(minLength: 0),
            panel_node,
            .spacer(minLength: 0),
        ]),
        .spacer(minLength: 0),
    ])

    // Dim backdrop + dismiss on click
    let backdropTapId = TapRegistry.shared.register { panel.cancel(); _panelBrowser = nil }
    let backdrop = ViewNode.onTap(id: backdropTapId, child:
        ViewNode.rect(width: nil, height: nil, fill: Color(red: 0, green: 0, blue: 0, opacity: 0.3))
    )

    return .zstack(children: [backdrop, centered])
}

// MARK: - Input handling (legacy — kept for keyboard support)

@MainActor
public func handleOpenPanelClick(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> Bool {
    // Click handling is now done through tap registry in the overlay
    return NSSavePanel._activePanel != nil
}

@MainActor
public func handleOpenPanelKey(keycode: UInt32) -> Bool {
    guard let panel = NSSavePanel._activePanel,
          let browser = _panelBrowser else { return false }

    switch keycode {
    case 126: // Up
        let entries = browser.entries
        if let currentId = browser.selectedEntryId,
           let idx = entries.firstIndex(where: { $0.id == currentId }), idx > 0 {
            browser.selectedEntryId = entries[idx - 1].id
        } else if let first = entries.first {
            browser.selectedEntryId = first.id
        }
    case 125: // Down
        let entries = browser.entries
        if let currentId = browser.selectedEntryId,
           let idx = entries.firstIndex(where: { $0.id == currentId }), idx < entries.count - 1 {
            browser.selectedEntryId = entries[idx + 1].id
        } else if let first = entries.first {
            browser.selectedEntryId = first.id
        }
    case 36: // Enter
        if let entry = browser.selectedEntry {
            if entry.isDirectory {
                browser.navigateTo(entry.id)
            } else {
                panel.resolve(path: entry.id)
            }
        }
    case 53: // Escape
        panel.cancel()
    default:
        return false
    }
    return true
}

@MainActor
public func updateOpenPanelMouse(x: CGFloat, y: CGFloat) {
    // Mouse tracking handled by SwiftUI hover system now
}
