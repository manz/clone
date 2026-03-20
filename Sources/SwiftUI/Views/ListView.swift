import Foundation

/// A container that presents rows of data in a single column.
/// Matches Apple's SwiftUI `List` struct.
public struct List: View {
    let children: [ViewNode]

    public init(@ViewBuilder content: () -> [ViewNode]) {
        self.children = content()
    }

    /// `List(data) { item in ... }` — data-driven list. Data must be Identifiable.
    public init<Data: RandomAccessCollection>(_ data: Data, @ViewBuilder rowContent: (Data.Element) -> [ViewNode]) where Data.Element: Identifiable {
        self.children = data.flatMap { rowContent($0) }
    }

    /// `List(data, id:) { item in ... }` — data-driven list with explicit id keypath.
    public init<Data: RandomAccessCollection, ID: Hashable>(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder rowContent: (Data.Element) -> [ViewNode]) {
        self.children = data.flatMap { rowContent($0) }
    }

    /// `List(data, selection:) { item in ... }` — data-driven list with selection binding.
    public init<Data: RandomAccessCollection, SelectionValue: Hashable>(_ data: Data, selection: Binding<SelectionValue?>?, @ViewBuilder rowContent: (Data.Element) -> [ViewNode]) where Data.Element: Identifiable {
        self.children = data.flatMap { rowContent($0) }
    }

    /// `List(data, id:, selection:) { item in ... }` — data-driven list with id and selection.
    public init<Data: RandomAccessCollection, ID: Hashable, SelectionValue: Hashable>(_ data: Data, id: KeyPath<Data.Element, ID>, selection: Binding<SelectionValue?>?, @ViewBuilder rowContent: (Data.Element) -> [ViewNode]) {
        self.children = data.flatMap { rowContent($0) }
    }

    /// `List(selection:) { ... }` — static list with selection binding.
    public init<SelectionValue: Hashable>(selection: Binding<SelectionValue?>?, @ViewBuilder content: () -> [ViewNode]) {
        self.children = content()
    }

    /// `List(selection: Set) { ... }` — static list with multi-selection binding.
    public init<SelectionValue: Hashable>(selection: Binding<Set<SelectionValue>>?, @ViewBuilder content: () -> [ViewNode]) {
        self.children = content()
    }

    public var body: ViewNode {
        .list(children: children)
    }
}
