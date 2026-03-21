import Foundation

/// `ForEach` — matches Apple's SwiftUI ForEach<Data, ID, Content>.
public struct ForEach<Data, ID: Hashable, Content: View>: _PrimitiveView {
    public let nodes: [ViewNode]

    public var _nodeRepresentation: ViewNode {
        if nodes.count == 1 { return nodes[0] }
        return .vstack(alignment: .leading, spacing: 0, children: nodes)
    }
}

// Identifiable collection
extension ForEach where Data: RandomAccessCollection, Data.Element: Identifiable, ID == Data.Element.ID {
    public init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.nodes = data.flatMap { _flattenToNodes(content($0)) }
    }
}

// Explicit id key path
extension ForEach where Data: RandomAccessCollection {
    public init(_ data: Data, id: KeyPath<Data.Element, ID>,
                @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.nodes = data.flatMap { _flattenToNodes(content($0)) }
    }
}

// Range<Int>
extension ForEach where Data == Range<Int>, ID == Int {
    public init(_ data: Range<Int>, @ViewBuilder content: @escaping (Int) -> Content) {
        self.nodes = data.flatMap { _flattenToNodes(content($0)) }
    }
}

// \.self id convenience
extension ForEach where Data: RandomAccessCollection, Data.Element: Hashable, ID == Data.Element {
    public init(_ data: Data, id: KeyPath<Data.Element, Data.Element>, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.nodes = data.flatMap { _flattenToNodes(content($0)) }
    }
}
