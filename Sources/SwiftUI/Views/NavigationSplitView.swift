import Foundation

/// NavigationSplitViewVisibility — controls column visibility.
public enum NavigationSplitViewVisibility: Sendable {
    case automatic, all, doubleColumn, detailOnly
}

/// A view that presents views in two or three columns.
/// Matches Apple's SwiftUI `NavigationSplitView` struct.
public struct NavigationSplitView: _PrimitiveView {
    let child: ViewNode

    private static func buildSplit(sidebarWidth: CGFloat, sidebarNodes: [ViewNode], detailNodes: [ViewNode]) -> ViewNode {
        // HStack: fixed sidebar + divider + detail fills rest via spacer
        // Each section clipped to prevent renderer batch ordering from mixing rects/text across sections
        // HStack: fixed sidebar + divider + detail fills rest
        .hstack(alignment: .top, spacing: 0, children: [
            ViewNode.frame(width: sidebarWidth, height: nil, child:
                .scrollView(axis: .vertical, children: [
                    ViewNode.vstack(alignment: .leading, spacing: 0, children: sidebarNodes)
                        .padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                ], key: "NavigationSplitView:sidebar")),
            ViewNode.rect(width: 1, height: nil, fill: WindowChrome.overlay),
            .clipped(radius: 0, child: ViewNode.frame(width: .infinity, height: nil, child:
                ViewNode.vstack(alignment: .leading, spacing: 0, children: detailNodes))),
        ])
    }

    public init(
        sidebarWidth: CGFloat = 220,
        @ViewBuilder sidebar: () -> some View,
        @ViewBuilder detail: () -> some View
    ) {
        self.child = Self.buildSplit(
            sidebarWidth: sidebarWidth,
            sidebarNodes: _flattenToNodes(sidebar()),
            detailNodes: _flattenToNodes(detail())
        )
    }

    /// `NavigationSplitView(columnVisibility:sidebar:detail:)` — with column visibility binding.
    public init(
        columnVisibility: Binding<NavigationSplitViewVisibility>,
        sidebarWidth: CGFloat = 220,
        @ViewBuilder sidebar: () -> some View,
        @ViewBuilder detail: () -> some View
    ) {
        self.child = Self.buildSplit(
            sidebarWidth: sidebarWidth,
            sidebarNodes: _flattenToNodes(sidebar()),
            detailNodes: _flattenToNodes(detail())
        )
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
            ViewNode.vstack(alignment: .leading, spacing: 0, children: contentNodes +
                [.spacer(minLength: 0)]),
            ViewNode.rect(width: 1, height: nil, fill: WindowChrome.overlay),
            ViewNode.vstack(alignment: .leading, spacing: 0, children: detailNodes +
                [.spacer(minLength: 0)]),
        ])
    }

    public var _nodeRepresentation: ViewNode {
        child
    }
}
