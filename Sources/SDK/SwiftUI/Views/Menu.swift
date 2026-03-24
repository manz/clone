import Foundation

/// A control for presenting a menu of actions.
/// Matches Apple's SwiftUI `Menu` struct.
public struct Menu: _PrimitiveView {
    let child: ViewNode

    /// `Menu("Label") { ... }` — collapsed menu with children.
    public init(_ label: String, @ViewBuilder content: () -> some View) {
        self.child = .menu(label: label, children: _flattenToNodes(content()))
    }

    /// `Menu { items } label: { Text("Label") }` — custom label variant (Apple's multi-closure pattern).
    public init(@ViewBuilder content: () -> some View, @ViewBuilder label: () -> some View) {
        let items = _flattenToNodes(content())
        self.child = .menu(label: "Menu", children: items)
    }

    /// `Menu { items } label: { Text("Label") } primaryAction: { action() }` — with primary action.
    public init(@ViewBuilder content: () -> some View, @ViewBuilder label: () -> some View, primaryAction: @escaping () -> Void) {
        let items = _flattenToNodes(content())
        self.child = .menu(label: "Menu", children: items)
    }

    public var _nodeRepresentation: ViewNode {
        child
    }
}
