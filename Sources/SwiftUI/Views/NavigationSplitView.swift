import Foundation

/// NavigationSplitViewVisibility — controls column visibility.
public enum NavigationSplitViewVisibility: Sendable {
    case automatic, all, doubleColumn, detailOnly
}

/// A view that presents views in two or three columns.
/// Matches Apple's SwiftUI `NavigationSplitView` struct.
public struct NavigationSplitView: View {
    let child: ViewNode

    public init(
        sidebarWidth: CGFloat = 220,
        @ViewBuilder sidebar: () -> [ViewNode],
        @ViewBuilder detail: () -> [ViewNode]
    ) {
        self.child = .hstack(alignment: .top, spacing: 0, children: [
            ViewNode.vstack(alignment: .leading, spacing: 0, children: sidebar()),
            ViewNode.rect(width: 1, height: nil, fill: WindowChrome.overlay),
            ViewNode.vstack(alignment: .leading, spacing: 0, children: detail()),
        ])
    }

    /// `NavigationSplitView(columnVisibility:sidebar:detail:)` — with column visibility binding.
    public init(
        columnVisibility: Binding<NavigationSplitViewVisibility>,
        sidebarWidth: CGFloat = 220,
        @ViewBuilder sidebar: () -> [ViewNode],
        @ViewBuilder detail: () -> [ViewNode]
    ) {
        self.child = .hstack(alignment: .top, spacing: 0, children: [
            ViewNode.vstack(alignment: .leading, spacing: 0, children: sidebar()),
            ViewNode.rect(width: 1, height: nil, fill: WindowChrome.overlay),
            ViewNode.vstack(alignment: .leading, spacing: 0, children: detail()),
        ])
    }

    /// Three-column variant: sidebar + content + detail.
    public init(
        columnVisibility: Binding<NavigationSplitViewVisibility> = .constant(.automatic),
        sidebarWidth: CGFloat = 220,
        @ViewBuilder sidebar: () -> [ViewNode],
        @ViewBuilder content: () -> [ViewNode],
        @ViewBuilder detail: () -> [ViewNode]
    ) {
        self.child = .hstack(alignment: .top, spacing: 0, children: [
            ViewNode.vstack(alignment: .leading, spacing: 0, children: sidebar()),
            ViewNode.rect(width: 1, height: nil, fill: WindowChrome.overlay),
            ViewNode.vstack(alignment: .leading, spacing: 0, children: content()),
            ViewNode.rect(width: 1, height: nil, fill: WindowChrome.overlay),
            ViewNode.vstack(alignment: .leading, spacing: 0, children: detail()),
        ])
    }

    public var body: ViewNode {
        child
    }
}
