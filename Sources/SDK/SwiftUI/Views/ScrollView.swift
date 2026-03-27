import Foundation

/// A scrollable view. Matches Apple's SwiftUI `ScrollView` struct.
/// Currently renders as VStack (scrolling not yet implemented).
public struct ScrollView<Content: View>: _PrimitiveView {
    let axes: Axis.Set
    let children: [ViewNode]
    let key: String

    public init(
        _ axes: Axis.Set = .vertical,
        showsIndicators: Bool = true,
        @ViewBuilder content: () -> Content,
        file: String = #fileID, line: Int = #line
    ) {
        self.axes = axes
        let scope = StateGraph.shared.currentScope
        self.key = scope.isEmpty ? "\(file):\(line)" : "\(scope)/\(file):\(line)"
        if let nodes = content() as? [ViewNode] { self.children = nodes }
        else { self.children = [_resolve(content())] }
    }

    public var _nodeRepresentation: ViewNode {
        .scrollView(axes: axes, children: children, key: key)
    }
}
