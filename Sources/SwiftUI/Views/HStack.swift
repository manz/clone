import Foundation

/// A view that arranges its children in a horizontal line.
/// Matches Apple's SwiftUI `HStack` struct.
public struct HStack: _PrimitiveView {
    let alignment: VAlignment
    let spacing: CGFloat
    let children: [ViewNode]

    public init<Content: View>(
        alignment: VAlignment = .center,
        spacing: CGFloat = 8,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.children = _flattenToNodes(content())
    }

    public var _nodeRepresentation: ViewNode {
        .hstack(alignment: alignment, spacing: spacing, children: children)
    }
}
