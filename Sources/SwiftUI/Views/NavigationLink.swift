import Foundation

/// A view that controls a navigation presentation.
/// On Clone, renders the label as a tappable element.
public struct NavigationLink<Label: View, Destination: View>: _PrimitiveView {
    let label: ViewNode
    let destination: ViewNode

    /// `NavigationLink(destination: SomeView()) { Text("Go") }`
    public init(destination: Destination, @ViewBuilder label: () -> Label) {
        self.destination = _resolve(destination)
        self.label = _resolve(label())
    }

    /// `NavigationLink { label } destination: { dest }`
    public init(@ViewBuilder destination: () -> Destination, @ViewBuilder label: () -> Label) {
        self.destination = _resolve(destination())
        self.label = _resolve(label())
    }

    public var _nodeRepresentation: ViewNode {
        label
    }
}

extension NavigationLink where Label == Text {
    /// Creates a navigation link with a text label.
    public init(_ titleKey: String, destination: Destination) {
        self.label = _resolve(Text(titleKey))
        self.destination = _resolve(destination)
    }

    /// `NavigationLink("title") { destination }` — trailing closure for destination.
    public init(_ titleKey: String, @ViewBuilder destination: () -> Destination) {
        self.label = _resolve(Text(titleKey))
        self.destination = _resolve(destination())
    }
}

extension NavigationLink where Destination == EmptyView {
    /// `NavigationLink(value:) { label }` — value-based navigation (NavigationStack).
    public init<V: Hashable>(value: V?, @ViewBuilder label: () -> Label) {
        self.label = _resolve(label())
        self.destination = _resolve(EmptyView())
    }
}

extension NavigationLink where Label == Text, Destination == EmptyView {
    /// `NavigationLink("title", value:)` — value-based with text label.
    public init<V: Hashable>(_ titleKey: String, value: V?) {
        self.label = _resolve(Text(titleKey))
        self.destination = _resolve(EmptyView())
    }
}
