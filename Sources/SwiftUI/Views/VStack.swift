import Foundation

/// A view that arranges its children in a vertical line.
/// Matches Apple's SwiftUI `VStack` struct.
public struct VStack: _PrimitiveView {
    let alignment: HAlignment
    let spacing: CGFloat
    let children: [ViewNode]

    public init<Content: View>(
        alignment: HAlignment = .center,
        spacing: CGFloat = 8,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.children = _flattenToNodes(content())
    }

    public var _nodeRepresentation: ViewNode {
        .vstack(alignment: alignment, spacing: spacing, children: children)
    }
}
