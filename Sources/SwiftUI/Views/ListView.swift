import Foundation

/// A container that presents rows of data in a single column.
/// Matches Apple's SwiftUI `List` struct.
public struct List: _PrimitiveView {
    let children: [ViewNode]

    public init(@ViewBuilder content: () -> some View) {
        self.children = _flattenToNodes(content())
    }

    /// `List(data) { item in ... }` — data-driven list. Data must be Identifiable.
    public init<Data: RandomAccessCollection>(_ data: Data, @ViewBuilder rowContent: (Data.Element) -> some View) where Data.Element: Identifiable {
        self.children = data.flatMap { _flattenToNodes(rowContent($0)) }
    }

    /// `List(data, id:) { item in ... }` — data-driven list with explicit id keypath.
    public init<Data: RandomAccessCollection, ID: Hashable>(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder rowContent: (Data.Element) -> some View) {
        self.children = data.flatMap { _flattenToNodes(rowContent($0)) }
    }

    /// `List(data, selection:) { item in ... }` — data-driven list with selection binding.
    public init<Data: RandomAccessCollection, SelectionValue: Hashable>(_ data: Data, selection: Binding<SelectionValue?>?, @ViewBuilder rowContent: (Data.Element) -> some View) where Data.Element: Identifiable {
        self.children = data.flatMap { _flattenToNodes(rowContent($0)) }
    }

    /// `List(data, id:, selection:) { item in ... }` — data-driven list with id and selection.
    public init<Data: RandomAccessCollection, ID: Hashable, SelectionValue: Hashable>(_ data: Data, id: KeyPath<Data.Element, ID>, selection: Binding<SelectionValue?>?, @ViewBuilder rowContent: (Data.Element) -> some View) {
        self.children = data.flatMap { _flattenToNodes(rowContent($0)) }
    }

    /// `List(selection:) { ... }` — static list with optional selection binding.
    public init<SelectionValue: Hashable>(selection: Binding<SelectionValue?>?, @ViewBuilder content: () -> some View) {
        let nodes = _flattenToNodes(content())
        if let binding = selection {
            self.children = Self.wrapWithSelection(nodes, binding: binding)
        } else {
            self.children = nodes
        }
    }

    /// `List(selection: Set) { ... }` — static list with multi-selection binding.
    public init<SelectionValue: Hashable>(selection: Binding<Set<SelectionValue>>?, @ViewBuilder content: () -> some View) {
        self.children = _flattenToNodes(content())
    }

    /// `List(selection: $value) { ... }` — non-optional selection binding.
    public init<SelectionValue: Hashable>(selection: Binding<SelectionValue>, @ViewBuilder content: () -> some View) {
        let nodes = _flattenToNodes(content())
        self.children = Self.wrapWithSelection(nodes, binding: binding(from: selection))
    }

    public var _nodeRepresentation: ViewNode {
        .list(children: children)
    }

    // MARK: - Selection wiring

    /// Wraps each child node with a tap handler that updates the selection binding.
    /// Uses 1-based index as tag value (matching common .tag(1), .tag(2) pattern).
    /// Persists selection across frame rebuilds via TagRegistry.
    private static func wrapWithSelection<V: Hashable>(_ nodes: [ViewNode], binding: Binding<V?>) -> [ViewNode] {
        let key = "list_selection_\(V.self)"

        // Restore persisted selection from previous frame
        if let persisted = TagRegistry.shared.getSelection(forKey: key) as? V {
            binding.wrappedValue = persisted
        }

        return nodes.enumerated().map { (index, node) in
            let tagValue: V?
            if let intTag = (index + 1) as? V {
                tagValue = intTag
            } else {
                tagValue = nil
            }

            if let value = tagValue {
                let tapId = TapRegistry.shared.register {
                    binding.wrappedValue = value
                    TagRegistry.shared.setSelection(AnyHashable(value), forKey: key)
                }
                return .onTap(id: tapId, child: node)
            }
            return node
        }
    }
}

/// Helper to convert non-optional binding to optional binding
private func binding<V: Hashable>(from nonOptional: Binding<V>) -> Binding<V?> {
    Binding<V?>(
        get: { nonOptional.wrappedValue },
        set: { if let v = $0 { nonOptional.wrappedValue = v } }
    )
}
