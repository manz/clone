import Foundation

/// A view that arranges its children in a horizontal line.
/// Matches Apple's SwiftUI `HStack` struct.
public struct HStack: View {
    let alignment: VAlignment
    let spacing: CGFloat
    let children: [ViewNode]

    public init(
        alignment: VAlignment = .center,
        spacing: CGFloat = 8,
        @ViewBuilder content: () -> [ViewNode]
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.children = content()
    }

    public var body: ViewNode {
        .hstack(alignment: alignment, spacing: spacing, children: children)
    }
}
