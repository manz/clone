import Foundation

/// A type-erased view that allows any view to be used where `some View` is expected.
public struct AnyView: _PrimitiveView {
    nonisolated(unsafe) let node: ViewNode

    nonisolated public init<V: View>(_ view: V) {
        self.node = _resolve(view)
    }

    public var _nodeRepresentation: ViewNode {
        node
    }
}

/// A transparent grouping container that doesn't affect layout.
public struct Group<Content: View>: _PrimitiveView {
    let content: [ViewNode]

    public init(@ViewBuilder content: () -> Content) {
        if let nodes = content() as? [ViewNode] {
            self.content = nodes
        } else {
            self.content = [_resolve(content())]
        }
    }

    public var _nodeRepresentation: ViewNode {
        if content.count == 1 {
            return content[0]
        }
        return .vstack(alignment: .leading, spacing: 0, children: content)
    }
}

/// An empty view that takes no space.
public struct EmptyView: _PrimitiveView {
    public init() {}
    public var _nodeRepresentation: ViewNode { .empty }
}
