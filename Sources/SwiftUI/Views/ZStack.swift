import Foundation

/// A view that overlays its children, aligning them in both axes.
/// Matches Apple's SwiftUI `ZStack` struct.
public struct ZStack: View {
    let children: [ViewNode]

    public init(@ViewBuilder content: () -> [ViewNode]) {
        self.children = content()
    }

    public var body: ViewNode {
        .zstack(children: children)
    }
}
