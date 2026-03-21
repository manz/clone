import Foundation

/// `ForEach` — matches Apple's SwiftUI ForEach. Produces views from a collection.
public struct ForEach<Data> {
    public let nodes: [ViewNode]
}

// Identifiable collection
extension ForEach where Data: RandomAccessCollection, Data.Element: Identifiable {
    public init(_ data: Data, @ViewBuilder content: (Data.Element) -> some View) {
        self.nodes = data.flatMap { _flattenToNodes(content($0)) }
    }
}

// Explicit id key path
extension ForEach where Data: RandomAccessCollection {
    public init<ID: Hashable>(_ data: Data, id: KeyPath<Data.Element, ID>,
                               @ViewBuilder content: (Data.Element) -> some View) {
        self.nodes = data.flatMap { _flattenToNodes(content($0)) }
    }
}

// Range<Int>
extension ForEach where Data == Range<Int> {
    public init(_ data: Range<Int>, @ViewBuilder content: (Int) -> some View) {
        self.nodes = data.flatMap { _flattenToNodes(content($0)) }
    }
}

// MARK: - View conformance

extension ForEach: _PrimitiveView {
    public var _nodeRepresentation: ViewNode {
        if nodes.count == 1 { return nodes[0] }
        return .vstack(alignment: .leading, spacing: 0, children: nodes)
    }
}
