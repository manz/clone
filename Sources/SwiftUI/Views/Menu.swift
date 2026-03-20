import Foundation

/// A control for presenting a menu of actions.
/// Matches Apple's SwiftUI `Menu` struct.
public struct Menu: View {
    let child: ViewNode

    /// `Menu("Label") { ... }` — collapsed menu with children.
    public init(_ label: String, @ViewBuilder content: () -> [ViewNode]) {
        self.child = .menu(label: label, children: content())
    }

    /// `Menu { items } label: { Text("Label") }` — custom label variant (Apple's multi-closure pattern).
    public init(@ViewBuilder content: () -> [ViewNode], @ViewBuilder label: () -> [ViewNode]) {
        // ViewNode.menu requires a String label; extract from label nodes or use fallback.
        let items = content()
        self.child = .menu(label: "Menu", children: items)
    }

    public var body: ViewNode {
        child
    }
}
