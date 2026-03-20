import Foundation

/// A view that switches between multiple child views using a tab bar.
/// Matches Apple's SwiftUI `TabView` struct.
public struct TabView<SelectionValue: Hashable, Content: View>: View {
    let selection: Binding<SelectionValue>?
    let content: [ViewNode]

    /// Creates a tab view with a bound selection value.
    public init(selection: Binding<SelectionValue>, @ViewBuilder content: () -> [ViewNode]) {
        self.selection = selection
        self.content = content()
    }

    public var body: ViewNode {
        // Render as VStack: content area on top, tab bar on bottom
        .vstack(alignment: .leading, spacing: 0, children: [
            // Content area — show all children stacked (selection filtering requires state tracking)
            .vstack(alignment: .leading, spacing: 0, children: content),
        ])
    }
}

extension TabView where SelectionValue == Int {
    /// Creates a tab view without explicit selection binding.
    public init(@ViewBuilder content: () -> [ViewNode]) {
        self.selection = nil
        self.content = content()
    }
}
