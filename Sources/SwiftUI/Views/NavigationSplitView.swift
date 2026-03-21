import Foundation

/// NavigationSplitViewVisibility — controls column visibility.
public enum NavigationSplitViewVisibility: Sendable {
    case automatic, all, doubleColumn, detailOnly
}

/// A view that presents views in two or three columns.
/// Matches Apple's SwiftUI `NavigationSplitView` struct.
public struct NavigationSplitView: _PrimitiveView {
    let child: ViewNode

    public init(
        sidebarWidth: CGFloat = 220,
        @ViewBuilder sidebar: () -> some View,
        @ViewBuilder detail: () -> some View
    ) {
        self.child = .hstack(alignment: .top, spacing: 0, children: [
            ViewNode.vstack(alignment: .leading, spacing: 0, children: _flattenToNodes(sidebar())),
            ViewNode.rect(width: 1, height: nil, fill: WindowChrome.overlay),
            ViewNode.vstack(alignment: .leading, spacing: 0, children: _flattenToNodes(detail())),
        ])
    }

    /// `NavigationSplitView(columnVisibility:sidebar:detail:)` — with column visibility binding.
    public init(
        columnVisibility: Binding<NavigationSplitViewVisibility>,
        sidebarWidth: CGFloat = 220,
        @ViewBuilder sidebar: () -> some View,
        @ViewBuilder detail: () -> some View
    ) {
        self.child = .hstack(alignment: .top, spacing: 0, children: [
            ViewNode.vstack(alignment: .leading, spacing: 0, children: _flattenToNodes(sidebar())),
            ViewNode.rect(width: 1, height: nil, fill: WindowChrome.overlay),
            ViewNode.vstack(alignment: .leading, spacing: 0, children: _flattenToNodes(detail())),
        ])
    }

    /// Three-column variant: sidebar + content + detail.
    public init(
        columnVisibility: Binding<NavigationSplitViewVisibility> = .constant(.automatic),
        sidebarWidth: CGFloat = 220,
        @ViewBuilder sidebar: () -> some View,
        @ViewBuilder content: () -> some View,
        @ViewBuilder detail: () -> some View
    ) {
        self.child = .hstack(alignment: .top, spacing: 0, children: [
            ViewNode.vstack(alignment: .leading, spacing: 0, children: _flattenToNodes(sidebar())),
            ViewNode.rect(width: 1, height: nil, fill: WindowChrome.overlay),
            ViewNode.vstack(alignment: .leading, spacing: 0, children: _flattenToNodes(content())),
            ViewNode.rect(width: 1, height: nil, fill: WindowChrome.overlay),
            ViewNode.vstack(alignment: .leading, spacing: 0, children: _flattenToNodes(detail())),
        ])
    }

    public var _nodeRepresentation: ViewNode {
        child
    }
}
