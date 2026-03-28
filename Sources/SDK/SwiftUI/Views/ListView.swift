import Foundation

/// A container that presents rows of data in a single column.
/// Matches Apple's SwiftUI `List` struct.
public struct List: _PrimitiveView {
    let children: [ViewNode]
    /// Non-nil when using lazy data-driven mode.
    let lazyKey: String?
    let lazyCount: Int
    /// Stable scroll key based on source location (not position).
    let scrollKey: String

    public init(@ViewBuilder content: () -> some View, file: String = #fileID, line: Int = #line) {
        self.children = _flattenToNodes(content())
        self.lazyKey = nil
        self.lazyCount = 0
        let scope = StateGraph.shared.currentScope
        self.scrollKey = scope.isEmpty ? "list/\(file):\(line)" : "list/\(scope)/\(file):\(line)"
    }

    /// `List(data) { item in ... }` — data-driven list with lazy row evaluation.
    public init<Data: RandomAccessCollection>(_ data: Data, @ViewBuilder rowContent: @escaping (Data.Element) -> some View, file: String = #fileID, line: Int = #line) where Data.Element: Identifiable {
        let items = Array(data)
        let key = "\(StateGraph.shared.currentScope)/\(file):\(line)"
        LazyRowRegistry.shared.register(key: key, count: items.count) { index in
            _resolve(rowContent(items[index]))
        }
        self.children = []
        self.lazyKey = key
        self.lazyCount = items.count
        let scope = StateGraph.shared.currentScope
        self.scrollKey = scope.isEmpty ? "list/\(file):\(line)" : "list/\(scope)/\(file):\(line)"
    }

    /// `List(data, id:) { item in ... }` — data-driven list with explicit id keypath.
    public init<Data: RandomAccessCollection, ID: Hashable>(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder rowContent: @escaping (Data.Element) -> some View, file: String = #fileID, line: Int = #line) {
        let items = Array(data)
        let key = "\(StateGraph.shared.currentScope)/\(file):\(line)"
        LazyRowRegistry.shared.register(key: key, count: items.count) { index in
            _resolve(rowContent(items[index]))
        }
        self.children = []
        self.lazyKey = key
        self.lazyCount = items.count
        let scope = StateGraph.shared.currentScope
        self.scrollKey = scope.isEmpty ? "list/\(file):\(line)" : "list/\(scope)/\(file):\(line)"
    }

    /// `List(data, selection:) { item in ... }` — data-driven list with selection binding.
    public init<Data: RandomAccessCollection, SelectionValue: Hashable>(_ data: Data, selection: Binding<SelectionValue?>?, @ViewBuilder rowContent: (Data.Element) -> some View, file: String = #fileID, line: Int = #line) where Data.Element: Identifiable {
        if let binding = selection {
            self.children = Self.wrapDataWithSelection(data, selection: binding, rowContent: rowContent)
        } else {
            self.children = data.flatMap { _flattenToNodes(rowContent($0)) }
        }
        self.lazyKey = nil; self.lazyCount = 0
        let scope = StateGraph.shared.currentScope
        self.scrollKey = scope.isEmpty ? "list/\(file):\(line)" : "list/\(scope)/\(file):\(line)"
    }

    /// `List(data, id:, selection:) { item in ... }` — data-driven list with id and selection.
    public init<Data: RandomAccessCollection, ID: Hashable, SelectionValue: Hashable>(_ data: Data, id: KeyPath<Data.Element, ID>, selection: Binding<SelectionValue?>?, @ViewBuilder rowContent: (Data.Element) -> some View, file: String = #fileID, line: Int = #line) {
        self.children = data.flatMap { _flattenToNodes(rowContent($0)) }
        self.lazyKey = nil; self.lazyCount = 0
        let scope = StateGraph.shared.currentScope
        self.scrollKey = scope.isEmpty ? "list/\(file):\(line)" : "list/\(scope)/\(file):\(line)"
    }

    /// `List(data, selection: Binding<Set<V>>) { ... }` — data-driven with multi-selection.
    public init<Data: RandomAccessCollection, SelectionValue: Hashable>(_ data: Data, selection: Binding<Set<SelectionValue>>, @ViewBuilder rowContent: (Data.Element) -> some View, file: String = #fileID, line: Int = #line) where Data.Element: Identifiable {
        self.children = Self.wrapDataWithSetSelection(data, selection: selection, rowContent: rowContent)
        self.lazyKey = nil; self.lazyCount = 0
        let scope = StateGraph.shared.currentScope
        self.scrollKey = scope.isEmpty ? "list/\(file):\(line)" : "list/\(scope)/\(file):\(line)"
    }

    /// `List(selection:) { ... }` — static list with optional selection binding.
    public init<SelectionValue: Hashable>(selection: Binding<SelectionValue?>?, @ViewBuilder content: () -> some View, file: String = #fileID, line: Int = #line) {
        let nodes = _flattenToNodes(content())
        if let binding = selection {
            self.children = Self.wrapWithSelection(nodes, binding: binding)
        } else {
            self.children = nodes
        }
        self.lazyKey = nil; self.lazyCount = 0
        let scope = StateGraph.shared.currentScope
        self.scrollKey = scope.isEmpty ? "list/\(file):\(line)" : "list/\(scope)/\(file):\(line)"
    }

    /// `List(selection: Set) { ... }` — static list with multi-selection binding.
    public init<SelectionValue: Hashable>(selection: Binding<Set<SelectionValue>>?, @ViewBuilder content: () -> some View, file: String = #fileID, line: Int = #line) {
        self.children = _flattenToNodes(content())
        self.lazyKey = nil; self.lazyCount = 0
        let scope = StateGraph.shared.currentScope
        self.scrollKey = scope.isEmpty ? "list/\(file):\(line)" : "list/\(scope)/\(file):\(line)"
    }

    /// `List(selection: $value) { ... }` — non-optional selection binding.
    public init<SelectionValue: Hashable>(selection: Binding<SelectionValue>, @ViewBuilder content: () -> some View, file: String = #fileID, line: Int = #line) {
        let nodes = _flattenToNodes(content())
        self.children = Self.wrapWithSelection(nodes, binding: binding(from: selection))
        self.lazyKey = nil; self.lazyCount = 0
        let scope = StateGraph.shared.currentScope
        self.scrollKey = scope.isEmpty ? "list/\(file):\(line)" : "list/\(scope)/\(file):\(line)"
    }

    public var _nodeRepresentation: ViewNode {
        if let key = lazyKey {
            return .lazyList(key: key, count: lazyCount)
        }
        return .list(children: children, scrollKey: scrollKey)
    }

    // MARK: - Selection wiring

    /// Data-driven list with single selection — uses item.id as selection value.
    private static func wrapDataWithSelection<Data: RandomAccessCollection, SelectionValue: Hashable>(
        _ data: Data, selection: Binding<SelectionValue?>,
        @ViewBuilder rowContent: (Data.Element) -> some View
    ) -> [ViewNode] where Data.Element: Identifiable {
        let key = "list_selection_\(SelectionValue.self)"
        if let persisted = TagRegistry.shared.getSelection(forKey: key) as? SelectionValue {
            selection.wrappedValue = persisted
        }
        return data.flatMap { item -> [ViewNode] in
            let nodes = _flattenToNodes(rowContent(item))
            guard let tagValue = item.id as? SelectionValue else { return nodes }
            return nodes.map { node in
                let tapId = TapRegistry.shared.register {
                    selection.wrappedValue = tagValue
                    TagRegistry.shared.setSelection(AnyHashable(tagValue), forKey: key)
                }
                return .onTap(id: tapId, child: node)
            }
        }
    }

    /// Data-driven list with multi-selection (Set) — uses item.id, toggles membership.
    private static func wrapDataWithSetSelection<Data: RandomAccessCollection, SelectionValue: Hashable>(
        _ data: Data, selection: Binding<Set<SelectionValue>>,
        @ViewBuilder rowContent: (Data.Element) -> some View
    ) -> [ViewNode] where Data.Element: Identifiable {
        let key = "list_set_selection_\(SelectionValue.self)"
        if let persisted = TagRegistry.shared.getSelection(forKey: key) as? Set<SelectionValue> {
            selection.wrappedValue = persisted
        }
        return data.flatMap { item -> [ViewNode] in
            let nodes = _flattenToNodes(rowContent(item))
            guard let tagValue = item.id as? SelectionValue else { return nodes }
            return nodes.map { node in
                let tapId = TapRegistry.shared.register {
                    // Single-click replaces selection (like macOS default)
                    selection.wrappedValue = [tagValue]
                    TagRegistry.shared.setSelection(AnyHashable(selection.wrappedValue), forKey: key)
                }
                return .onTap(id: tapId, child: node)
            }
        }
    }

    /// Wraps each child with a tap handler using its .tag() value or index fallback.
    private static func wrapWithSelection<V: Hashable>(_ nodes: [ViewNode], binding: Binding<V?>) -> [ViewNode] {
        let key = "list_selection_\(V.self)"

        // Restore persisted selection from previous frame
        if let persisted = TagRegistry.shared.getSelection(forKey: key) as? V {
            binding.wrappedValue = persisted
        }

        return nodes.enumerated().map { (index, node) in
            // Extract tag value from .tagged node, or fall back to index
            let tagValue: V?
            if let extracted = Self.extractTag(from: node) as? V {
                tagValue = extracted
            } else if let intTag = (index + 1) as? V {
                tagValue = intTag
            } else {
                tagValue = nil
            }

            if let value = tagValue {
                let isSelected = binding.wrappedValue == value
                let tapId = TapRegistry.shared.register {
                    binding.wrappedValue = value
                    TagRegistry.shared.setSelection(AnyHashable(value), forKey: key)
                }
                // Selection highlight: rounded blue background
                let highlighted: ViewNode = isSelected
                    ? node.background(Color.accentColor.opacity(0.2), cornerRadius: 6)
                    : node
                return .onTap(id: tapId, child: highlighted)
            }
            return node
        }
    }

    /// Walk a ViewNode to find a .tagged value.
    private static func extractTag(from node: ViewNode) -> AnyHashable? {
        switch node {
        case .tagged(let tag, _): return tag.value
        case .padding(_, let child): return extractTag(from: child)
        case .frame(_, _, let child): return extractTag(from: child)
        case .onTap(_, let child): return extractTag(from: child)
        case .contextMenu(let child, _): return extractTag(from: child)
        default: return nil
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
