import Foundation

/// A scrollable view. Matches Apple's SwiftUI `ScrollView` struct.
/// Currently renders as VStack (scrolling not yet implemented).
public struct ScrollView: View {
    let axis: Axis
    let children: [ViewNode]

    public init(
        _ axis: Axis = .vertical,
        @ViewBuilder content: () -> [ViewNode]
    ) {
        self.axis = axis
        self.children = content()
    }

    public var body: ViewNode {
        .scrollView(axis: axis, children: children)
    }
}
