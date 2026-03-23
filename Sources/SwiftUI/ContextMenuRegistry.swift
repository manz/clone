import Foundation

/// Tracks the currently open context menu.
public final class ContextMenuRegistry: @unchecked Sendable {
    public static let shared = ContextMenuRegistry()

    /// Whether a context menu is currently open.
    public private(set) var isOpen = false

    /// The menu items to display.
    public private(set) var menuItems: [ViewNode] = []

    /// Position where the menu was opened (in content coordinates).
    public private(set) var position: CGPoint = .zero

    /// Tap handlers for menu items (registered when menu opens).
    public private(set) var itemActions: [UInt64] = []

    private init() {}

    /// Open a context menu at the given position.
    public func open(items: [ViewNode], x: CGFloat, y: CGFloat) {
        self.menuItems = items
        self.position = CGPoint(x: x, y: y)
        self.isOpen = true
    }

    /// Close the context menu.
    public func close() {
        self.isOpen = false
        self.menuItems = []
        self.itemActions = []
    }

    /// Full reset.
    public func clear() {
        close()
    }
}
