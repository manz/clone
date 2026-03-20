import Foundation

/// A view that overlays its children, aligning them in both axes.
/// Matches Apple's SwiftUI `ZStack` struct.
public struct ZStack: View {
    let children: [ViewNode]

    public init(alignment: Alignment = .center, @ViewBuilder content: () -> [ViewNode]) {
        self.children = content()
    }

    public var body: ViewNode {
        .zstack(children: children)
    }
}
