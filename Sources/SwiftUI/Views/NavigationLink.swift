import Foundation

/// A view that controls a navigation presentation.
/// On Clone, renders the label as a tappable element.
public struct NavigationLink<Label: View, Destination: View>: View {
    let label: ViewNode
    let destination: ViewNode

    public init(@ViewBuilder destination: () -> Destination, @ViewBuilder label: () -> Label) {
        self.destination = _resolve(destination())
        self.label = _resolve(label())
    }

    public var body: ViewNode {
        label
    }
}

extension NavigationLink where Label == Text {
    /// Creates a navigation link with a text label.
    public init(_ titleKey: String, @ViewBuilder destination: () -> Destination) {
        self.label = Text(titleKey).body
        self.destination = _resolve(destination())
    }
}
