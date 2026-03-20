import Foundation

/// A view that displays a root view and enables programmatic navigation.
/// Matches Apple's SwiftUI `NavigationStack` struct.
/// Navigation state is window-managed on Clone.
public struct NavigationStack: View {
    let children: [ViewNode]

    public init(@ViewBuilder content: () -> [ViewNode]) {
        self.children = content()
    }

    public var body: ViewNode {
        .navigationStack(children: children)
    }
}
