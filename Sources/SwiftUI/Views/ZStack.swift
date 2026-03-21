import Foundation

/// A view that overlays its children, aligning them in both axes.
/// Matches Apple's SwiftUI `ZStack` struct.
public struct ZStack: _PrimitiveView {
    let children: [ViewNode]

    public init(alignment: Alignment = .center, @ViewBuilder content: () -> [ViewNode]) {
        self.children = content()
    }

    public var _nodeRepresentation: ViewNode {
        .zstack(children: children)
    }
}
