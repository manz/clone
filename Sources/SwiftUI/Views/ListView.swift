import Foundation

/// A container that presents rows of data in a single column.
/// Matches Apple's SwiftUI `List` struct.
public struct List: View {
    let children: [ViewNode]

    public init(@ViewBuilder content: () -> [ViewNode]) {
        self.children = content()
    }

    public var body: ViewNode {
        .list(children: children)
    }
}
