import Foundation

/// A view that displays a root view and enables programmatic navigation.
/// Matches Apple's SwiftUI `NavigationStack` struct.
/// Navigation state is window-managed on Clone.
public struct NavigationStack: _PrimitiveView {
    let children: [ViewNode]

    public init(@ViewBuilder content: () -> some View) {
        self.children = _flattenToNodes(content())
    }

    /// `NavigationStack(path:) { content }` — programmatic navigation with a binding path.
    public init(path: Binding<NavigationPath>, @ViewBuilder content: () -> some View) {
        self.children = _flattenToNodes(content())
    }

    /// `NavigationStack(path: Binding<[T]>) { content }` — programmatic navigation with typed path.
    public init<Data: MutableCollection & RangeReplaceableCollection & RandomAccessCollection>(path: Binding<Data>, @ViewBuilder content: () -> some View) where Data.Element: Hashable {
        self.children = _flattenToNodes(content())
    }

    public var _nodeRepresentation: ViewNode {
        .navigationStack(children: children)
    }
}
