import Foundation

/// A view that displays a root view and enables programmatic navigation.
/// Matches Apple's SwiftUI `NavigationStack` struct.
/// Navigation state is window-managed on Clone.
public struct NavigationStack: View {
    let children: [ViewNode]

    public init(@ViewBuilder content: () -> [ViewNode]) {
        self.children = content()
    }

    /// `NavigationStack(path:) { content }` — programmatic navigation with a binding path.
    public init(path: Binding<NavigationPath>, @ViewBuilder content: () -> [ViewNode]) {
        self.children = content()
    }

    /// `NavigationStack(path: Binding<[T]>) { content }` — programmatic navigation with typed path.
    public init<Data: MutableCollection & RangeReplaceableCollection & RandomAccessCollection>(path: Binding<Data>, @ViewBuilder content: () -> [ViewNode]) where Data.Element: Hashable {
        self.children = content()
    }

    public var body: ViewNode {
        .navigationStack(children: children)
    }
}
