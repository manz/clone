import Foundation

/// A view that controls a navigation presentation.
/// On Clone, renders the label as a tappable element.
/// Destination is lazily resolved — only built when actually navigated to.
public struct NavigationLink<Label: View, Destination: View>: _PrimitiveView {
    let label: ViewNode
    /// Destination is NOT resolved during init — only when navigation occurs.
    /// This prevents expensive view bodies (network fetches, DB queries) from
    /// running for every item in a ForEach.
    let destinationBuilder: () -> ViewNode

    /// `NavigationLink(destination: SomeView()) { Text("Go") }`
    public init(destination: @autoclosure @escaping () -> Destination, @ViewBuilder label: () -> Label) {
        self.destinationBuilder = { _resolve(destination()) }
        self.label = _resolve(_flattenToNodes(label()))
    }

    /// `NavigationLink { label } destination: { dest }`
    public init(@ViewBuilder destination: @escaping () -> Destination, @ViewBuilder label: () -> Label) {
        self.destinationBuilder = { _resolve(destination()) }
        self.label = _resolve(_flattenToNodes(label()))
    }

    public var _nodeRepresentation: ViewNode {
        label
    }
}

extension NavigationLink where Label == Text {
    /// Creates a navigation link with a text label.
    public init(_ titleKey: String, destination: @autoclosure @escaping () -> Destination) {
        self.label = _resolve(Text(titleKey))
        self.destinationBuilder = { _resolve(destination()) }
    }

    /// `NavigationLink("title") { destination }` — trailing closure for destination.
    public init(_ titleKey: String, @ViewBuilder destination: @escaping () -> Destination) {
        self.label = _resolve(Text(titleKey))
        self.destinationBuilder = { _resolve(destination()) }
    }
}

extension NavigationLink where Destination == EmptyView {
    /// `NavigationLink(value:) { label }` — value-based navigation (NavigationStack).
    public init<V: Hashable>(value: V?, @ViewBuilder label: () -> Label) {
        self.label = _resolve(_flattenToNodes(label()))
        self.destinationBuilder = { _resolve(EmptyView()) }
    }
}

extension NavigationLink where Label == Text, Destination == EmptyView {
    /// `NavigationLink("title", value:)` — value-based with text label.
    public init<V: Hashable>(_ titleKey: String, value: V?) {
        self.label = _resolve(Text(titleKey))
        self.destinationBuilder = { _resolve(EmptyView()) }
    }
}
