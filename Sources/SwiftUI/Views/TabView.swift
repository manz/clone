import Foundation

/// A view that switches between multiple child views using a tab bar.
/// Matches Apple's SwiftUI `TabView` struct.
public struct TabView<SelectionValue: Hashable, Content: View>: View {
    let selection: Binding<SelectionValue>?
    let content: [ViewNode]

    /// Creates a tab view with a bound selection value.
    public init(selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {
        self.selection = selection
        if let nodes = content() as? [ViewNode] { self.content = nodes }
        else { self.content = [_resolve(content())] }
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
    public init(@ViewBuilder content: () -> Content) {
        self.selection = nil
        if let nodes = content() as? [ViewNode] { self.content = nodes }
        else { self.content = [_resolve(content())] }
    }
}

/// A single tab in a TabView — matches Apple's SwiftUI Tab (iOS 18+/macOS 15+).
public struct Tab<Value: Hashable, Content: View>: View {
    let child: ViewNode

    public init(_ title: String, systemImage: String, value: Value, @ViewBuilder content: () -> Content) {
        self.child = _resolve(content())
    }

    public init(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.child = _resolve(content())
    }

    public var body: ViewNode { child }
}

extension Tab where Value == Never {
    public init(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.child = _resolve(content())
    }
}
