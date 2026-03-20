import Foundation

/// `ForEach` — matches Apple's SwiftUI ForEach. Produces views from a collection.
///
/// Usage:
/// ```swift
/// ForEach(items) { item in Text(item.name) }          // Identifiable
/// ForEach(items, id: \.self) { item in Text(item) }   // explicit id
/// ForEach(0..<5) { i in Text("\(i)") }                 // range
/// ```
public struct ForEach<Data> {
    public let nodes: [ViewNode]
}

// Identifiable collection
extension ForEach where Data: RandomAccessCollection, Data.Element: Identifiable {
    public init(_ data: Data, @ViewBuilder content: (Data.Element) -> [ViewNode]) {
        self.nodes = data.flatMap { content($0) }
    }
}

// Explicit id key path
extension ForEach where Data: RandomAccessCollection {
    public init<ID: Hashable>(_ data: Data, id: KeyPath<Data.Element, ID>,
                               @ViewBuilder content: (Data.Element) -> [ViewNode]) {
        self.nodes = data.flatMap { content($0) }
    }
}

// Range<Int>
extension ForEach where Data == Range<Int> {
    public init(_ data: Range<Int>, @ViewBuilder content: (Int) -> [ViewNode]) {
        self.nodes = data.flatMap { content($0) }
    }
}

// MARK: - View conformance

extension ForEach: View {
    public var body: ViewNode {
        if nodes.count == 1 { return nodes[0] }
        return .vstack(alignment: .leading, spacing: 0, children: nodes)
    }
}
