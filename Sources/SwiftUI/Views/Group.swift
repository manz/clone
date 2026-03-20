import Foundation

/// A type-erased view that allows any view to be used where `some View` is expected.
public struct AnyView: View {
    let node: ViewNode

    public init<V: View>(_ view: V) {
        self.node = _resolve(view)
    }

    public var body: ViewNode {
        node
    }
}

/// A transparent grouping container that doesn't affect layout.
public struct Group<Content: View>: View {
    let content: [ViewNode]

    public init(@ViewBuilder content: () -> [ViewNode]) {
        self.content = content()
    }

    public var body: ViewNode {
        if content.count == 1 {
            return content[0]
        }
        return .vstack(alignment: .leading, spacing: 0, children: content)
    }
}

/// An empty view that takes no space.
public struct EmptyView: View {
    public init() {}
    public var body: ViewNode { .empty }
}
