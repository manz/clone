import Foundation

/// A control for presenting a menu of actions.
/// Matches Apple's SwiftUI `Menu` struct.
public struct Menu: View {
    let child: ViewNode

    /// `Menu("Label") { ... }` — collapsed menu with children.
    public init(_ label: String, @ViewBuilder content: () -> [ViewNode]) {
        self.child = .menu(label: label, children: content())
    }

    public var body: ViewNode {
        child
    }
}
