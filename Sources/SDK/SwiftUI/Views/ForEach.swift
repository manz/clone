import Foundation

/// `ForEach` — matches Apple's SwiftUI ForEach<Data, ID, Content>.
public struct ForEach<Data, ID: Hashable, Content: View>: _PrimitiveView {
    public let nodes: [ViewNode]

    public var _nodeRepresentation: ViewNode {
        if nodes.count == 1 { return nodes[0] }
        return .vstack(alignment: .leading, spacing: 0, children: nodes)
    }
}

// Identifiable collection — uses item.id as scope for stable state identity
extension ForEach where Data: RandomAccessCollection, Data.Element: Identifiable, ID == Data.Element.ID {
    public init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.nodes = data.flatMap { item in
            StateGraph.shared.pushScope("\(item.id)")
            let nodes = _flattenToNodes(content(item))
            StateGraph.shared.popScope()
            return nodes
        }
    }
}

// Explicit id key path — uses extracted id as scope
extension ForEach where Data: RandomAccessCollection {
    public init(_ data: Data, id: KeyPath<Data.Element, ID>,
                @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.nodes = data.flatMap { item in
            StateGraph.shared.pushScope("\(item[keyPath: id])")
            let nodes = _flattenToNodes(content(item))
            StateGraph.shared.popScope()
            return nodes
        }
    }
}

// Range<Int> — index is the id
extension ForEach where Data == Range<Int>, ID == Int {
    public init(_ data: Range<Int>, @ViewBuilder content: @escaping (Int) -> Content) {
        self.nodes = data.flatMap { index in
            StateGraph.shared.pushScope("\(index)")
            let nodes = _flattenToNodes(content(index))
            StateGraph.shared.popScope()
            return nodes
        }
    }
}

// _ForEachProtocol conformance so _flattenToNodes extracts children directly
// instead of falling through to _nodeRepresentation's vstack wrapper.
extension ForEach: @preconcurrency _ForEachProtocol {
    public var _flatNodes: [ViewNode] { nodes }
}

// \.self id convenience
extension ForEach where Data: RandomAccessCollection, Data.Element: Hashable, ID == Data.Element {
    public init(_ data: Data, id: KeyPath<Data.Element, Data.Element>, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.nodes = data.flatMap { item in
            StateGraph.shared.pushScope("\(item[keyPath: id])")
            let nodes = _flattenToNodes(content(item))
            StateGraph.shared.popScope()
            return nodes
        }
    }
}
