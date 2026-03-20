import Foundation

/// A container view that groups content with an optional header.
/// Matches Apple's SwiftUI `Section` struct.
public struct Section: View {
    let child: ViewNode

    public init(
        _ header: String? = nil,
        @ViewBuilder content: () -> [ViewNode]
    ) {
        var children: [ViewNode] = []
        if let header {
            children.append(
                ViewNode.text(header, fontSize: 12, color: .secondary, weight: .semibold)
            )
        }
        let rows = content()
        for (i, row) in rows.enumerated() {
            children.append(row)
            if i < rows.count - 1 {
                children.append(
                    ViewNode.rect(width: nil, height: 1, fill: WindowChrome.overlay)
                        .padding(.leading, 12)
                )
            }
        }
        self.child = .vstack(alignment: .leading, spacing: 0, children: children)
    }

    /// `Section(header:) { content }` — header parameter label variant.
    public init<H: View>(header: H, @ViewBuilder content: () -> [ViewNode]) {
        var children: [ViewNode] = [_resolve(header)]
        let rows = content()
        for (i, row) in rows.enumerated() {
            children.append(row)
            if i < rows.count - 1 {
                children.append(
                    ViewNode.rect(width: nil, height: 1, fill: WindowChrome.overlay)
                        .padding(.leading, 12)
                )
            }
        }
        self.child = .vstack(alignment: .leading, spacing: 0, children: children)
    }

    /// `Section { content } header: { header }` — Apple's multi-trailing-closure pattern.
    public init(@ViewBuilder content: () -> [ViewNode], @ViewBuilder header: () -> [ViewNode]) {
        let headerNodes = header()
        let headerNode = headerNodes.count == 1 ? headerNodes[0] : ViewNode.hstack(alignment: .center, spacing: 4, children: headerNodes)
        var children: [ViewNode] = [headerNode]
        let rows = content()
        for (i, row) in rows.enumerated() {
            children.append(row)
            if i < rows.count - 1 {
                children.append(
                    ViewNode.rect(width: nil, height: 1, fill: WindowChrome.overlay)
                        .padding(.leading, 12)
                )
            }
        }
        self.child = .vstack(alignment: .leading, spacing: 0, children: children)
    }

    /// `Section { content } header: { header } footer: { footer }` — with footer.
    public init(@ViewBuilder content: () -> [ViewNode], @ViewBuilder header: () -> [ViewNode], @ViewBuilder footer: () -> [ViewNode]) {
        let headerNodes = header()
        let headerNode = headerNodes.count == 1 ? headerNodes[0] : ViewNode.hstack(alignment: .center, spacing: 4, children: headerNodes)
        let footerNodes = footer()
        let footerNode = footerNodes.count == 1 ? footerNodes[0] : ViewNode.hstack(alignment: .center, spacing: 4, children: footerNodes)
        var children: [ViewNode] = [headerNode]
        let rows = content()
        for (i, row) in rows.enumerated() {
            children.append(row)
            if i < rows.count - 1 {
                children.append(
                    ViewNode.rect(width: nil, height: 1, fill: WindowChrome.overlay)
                        .padding(.leading, 12)
                )
            }
        }
        children.append(footerNode)
        self.child = .vstack(alignment: .leading, spacing: 0, children: children)
    }

    public var body: ViewNode {
        child
    }
}
