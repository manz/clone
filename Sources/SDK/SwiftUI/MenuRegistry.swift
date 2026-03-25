import Foundation
import CloneProtocol

/// Collects menus from .commands { } blocks during scene evaluation.
/// Converts SwiftUI CommandMenu/CommandGroup into AppMenu data for IPC.
public final class MenuRegistry: @unchecked Sendable {
    public static let shared = MenuRegistry()

    /// Menus collected during the current commands block.
    private var currentMenus: [AppMenu] = []

    /// Whether we're currently inside a collectFromCommands call.
    private var collecting = false

    /// Action closures keyed by menu item ID — fired when onMenuAction arrives.
    nonisolated(unsafe) public var actions: [String: () -> Void] = [:]

    private init() {}

    /// Evaluate a commands block and return the collected menus.
    @MainActor
    public func collectFromCommands(@ViewBuilder content: () -> some View) -> [AppMenu] {
        currentMenus = []
        collecting = true
        let _ = content() // triggers CommandMenu/CommandGroup inits which call addMenu
        collecting = false
        return currentMenus
    }

    /// Called by CommandMenu/CommandGroup during init to register a menu.
    public func addMenu(_ menu: AppMenu) {
        guard collecting else { return }
        currentMenus.append(menu)
    }

    /// Full reset.
    public func clear() {
        currentMenus = []
        collecting = false
    }
}

/// Extract menu items from a ViewBuilder's content.
/// Walks the ViewNode tree to find Button texts and Dividers.
@MainActor
public func _extractMenuItems(_ view: some View) -> [AppMenuItem] {
    let nodes = _flattenToNodes(view)
    return nodes.flatMap { _menuItemsFromNode($0) }
}

/// Walk a ViewNode and extract AppMenuItems.
public func _menuItemsFromNode(_ node: ViewNode) -> [AppMenuItem] {
    switch node {
    case .text(let content, _, _, _):
        // A standalone text — likely a Button label
        return [AppMenuItem(id: content.lowercased().replacingOccurrences(of: " ", with: "."),
                           title: content, shortcut: nil, isSeparator: false)]
    case .rect(_, let height, _) where height == 1:
        // Divider
        return [AppMenuItem(id: "separator", title: "", shortcut: nil, isSeparator: true)]
    case .onTap(let tapId, let child):
        // Extract the label, then wire the tap action to the menu item ID
        let items = _menuItemsFromNode(child)
        for item in items where !item.isSeparator {
            MenuRegistry.shared.actions[item.id] = { TapRegistry.shared.fire(id: tapId) }
        }
        return items
    case .hstack(_, _, let children), .vstack(_, _, let children), .zstack(_, let children):
        return children.flatMap { _menuItemsFromNode($0) }
    case .padding(_, let child), .frame(_, _, let child):
        return _menuItemsFromNode(child)
    case .empty:
        return []
    default:
        return []
    }
}
