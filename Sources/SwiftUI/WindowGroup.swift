/// A scene that presents a group of identically structured windows.
public struct WindowGroup<Content: View>: Scene {
    public typealias Body = _NeverScene
    public var body: _NeverScene { fatalError("WindowGroup is a primitive scene") }

    public let title: String
    public let content: () -> Content

    public init(_ title: String = "", @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
}

// ViewBuilder variant that returns [ViewNode]
extension WindowGroup where Content == ViewNode {
    public init(_ title: String = "", @ViewBuilder content: @escaping () -> [ViewNode]) {
        self.title = title
        // Wrap multiple nodes in a VStack
        self.content = {
            let nodes = content()
            if nodes.count == 1 { return nodes[0] }
            return ViewNode.vstack(alignment: .leading, spacing: 0, children: nodes)
        }
    }
}
