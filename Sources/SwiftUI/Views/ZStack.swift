import Foundation

/// A view that overlays its children, aligning them in both axes.
/// Matches Apple's SwiftUI `ZStack` struct.
public struct ZStack: _PrimitiveView {
    let children: [ViewNode]

    public init<Content: View>(
        alignment: Alignment = .center,
        @ViewBuilder content: () -> Content
    ) {
        self.children = _flattenToNodes(content())
    }

    public var _nodeRepresentation: ViewNode {
        .zstack(children: children)
    }
}
