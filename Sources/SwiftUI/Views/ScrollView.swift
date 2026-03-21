import Foundation

/// A scrollable view. Matches Apple's SwiftUI `ScrollView` struct.
/// Currently renders as VStack (scrolling not yet implemented).
public struct ScrollView<Content: View>: View {
    let axis: Axis
    let children: [ViewNode]

    public init(
        _ axis: Axis.Set = .vertical,
        showsIndicators: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.axis = axis.contains(.horizontal) ? .horizontal : .vertical
        if let nodes = content() as? [ViewNode] { self.children = nodes }
        else { self.children = [_resolve(content())] }
    }

    public var body: ViewNode {
        .scrollView(axis: axis, children: children)
    }
}
