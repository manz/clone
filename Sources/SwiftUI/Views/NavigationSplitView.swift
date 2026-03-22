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
        let sidebarNodes = _flattenToNodes(sidebar())
        let detailNodes = _flattenToNodes(detail())
        self.child = .hstack(alignment: .top, spacing: 0, children: [
            ViewNode.frame(width: sidebarWidth, height: nil, child:
                .vstack(alignment: .leading, spacing: 0, children: sidebarNodes)),
            ViewNode.rect(width: 1, height: nil, fill: WindowChrome.overlay),
            ViewNode.vstack(alignment: .leading, spacing: 0, children: detailNodes),
        ])
    }

    /// `NavigationSplitView(columnVisibility:sidebar:detail:)` — with column visibility binding.
    public init(
        columnVisibility: Binding<NavigationSplitViewVisibility>,
        sidebarWidth: CGFloat = 220,
        @ViewBuilder sidebar: () -> some View,
        @ViewBuilder detail: () -> some View
    ) {
        let sidebarNodes = _flattenToNodes(sidebar())
        let detailNodes = _flattenToNodes(detail())
        self.child = .hstack(alignment: .top, spacing: 0, children: [
            ViewNode.frame(width: sidebarWidth, height: nil, child:
                .vstack(alignment: .leading, spacing: 0, children: sidebarNodes)),
            ViewNode.rect(width: 1, height: nil, fill: WindowChrome.overlay),
            ViewNode.vstack(alignment: .leading, spacing: 0, children: detailNodes),
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
        let sidebarNodes = _flattenToNodes(sidebar())
        let contentNodes = _flattenToNodes(content())
        let detailNodes = _flattenToNodes(detail())
        self.child = .hstack(alignment: .top, spacing: 0, children: [
            ViewNode.frame(width: sidebarWidth, height: nil, child:
                .vstack(alignment: .leading, spacing: 0, children: sidebarNodes)),
            ViewNode.rect(width: 1, height: nil, fill: WindowChrome.overlay),
            ViewNode.vstack(alignment: .leading, spacing: 0, children: contentNodes),
            ViewNode.rect(width: 1, height: nil, fill: WindowChrome.overlay),
            ViewNode.vstack(alignment: .leading, spacing: 0, children: detailNodes),
        ])
    }

    public var _nodeRepresentation: ViewNode {
        child
    }
}
