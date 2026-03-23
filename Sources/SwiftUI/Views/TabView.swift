import Foundation

// MARK: - Tab Entry

/// Type-erased tab entry holding a selection value and its content.
public struct _AnyTabEntry {
    let value: AnyHashable
    let content: ViewNode
}

// MARK: - TabContent protocol

/// Protocol for content that can appear inside a TabView.
/// Carries the `SelectionValue` type so `Tab(value: .case)` resolves correctly.
@MainActor @preconcurrency
public protocol TabContent<SelectionValue> {
    associatedtype SelectionValue: Hashable
    var _tabEntries: [_AnyTabEntry] { get }
}

// MARK: - TabView

/// A view that switches between multiple child views using a tab bar.
public struct TabView<SelectionValue: Hashable, Content>: _PrimitiveView {
    let entries: [_AnyTabEntry]
    let selection: Binding<SelectionValue>?

    public var _nodeRepresentation: ViewNode {
        guard !entries.isEmpty else { return .empty }
        if let selection = selection {
            let target = AnyHashable(selection.wrappedValue)
            if let match = entries.first(where: { $0.value == target }) {
                return match.content
            }
        }
        // No match or no selection — show first tab
        return entries[0].content
    }
}

extension TabView where Content: TabContent<SelectionValue> {
    /// `TabView(selection:) { Tab(...) }` — typed tab content.
    public init(selection: Binding<SelectionValue>, @TabContentBuilder<SelectionValue> content: () -> Content) {
        self.entries = content()._tabEntries
        self.selection = selection
    }
}

extension TabView where Content: View, SelectionValue == Int {
    /// `TabView { ... }` — untyped, no selection.
    public init(@ViewBuilder content: () -> Content) {
        if let nodes = content() as? [ViewNode] {
            self.entries = nodes.enumerated().map { _AnyTabEntry(value: AnyHashable($0.offset), content: $0.element) }
        } else {
            self.entries = [_AnyTabEntry(value: AnyHashable(0), content: _resolve(content()))]
        }
        self.selection = nil
    }
}

// MARK: - Tab

/// A single tab in a TabView.
/// `Value` is inferred from `TabContentBuilder<SelectionValue>`.
public struct Tab<Value: Hashable, Content: View>: TabContent {
    public typealias SelectionValue = Value
    let tabValue: Value
    let child: ViewNode

    public init(_ title: String, systemImage: String, value: Value, @ViewBuilder content: () -> Content) {
        self.tabValue = value
        self.child = _resolve(content())
    }

    public var _tabEntries: [_AnyTabEntry] {
        [_AnyTabEntry(value: AnyHashable(tabValue), content: child)]
    }
}

extension Tab: _PrimitiveView {
    public var _nodeRepresentation: ViewNode { child }
}

extension Tab where Value == Never {
    public init(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        // Never is uninhabited — this init is for tabs without explicit selection value
        fatalError("Tab<Never> should not be used with value-based TabView")
    }
}

// MARK: - TabContentBuilder

/// Result builder that propagates `SelectionValue` from `TabView(selection:)` into `Tab(value:)`.
@resultBuilder
public struct TabContentBuilder<SelectionValue: Hashable> {
    /// Wrapper that holds accumulated tab entries.
    public struct TabGroup: TabContent {
        public let _tabEntries: [_AnyTabEntry]
    }

    // buildExpression constrains Tab's Value to match SelectionValue via bidirectional inference.
    public static func buildExpression<C: View>(_ tab: Tab<SelectionValue, C>) -> TabGroup {
        TabGroup(_tabEntries: tab._tabEntries)
    }

    public static func buildPartialBlock(first: TabGroup) -> TabGroup { first }

    public static func buildPartialBlock(accumulated: TabGroup, next: TabGroup) -> TabGroup {
        TabGroup(_tabEntries: accumulated._tabEntries + next._tabEntries)
    }

    public static func buildBlock(_ content: TabGroup) -> TabGroup { content }

    public static func buildOptional(_ component: TabGroup?) -> TabGroup {
        component ?? TabGroup(_tabEntries: [])
    }

    public static func buildEither(first component: TabGroup) -> TabGroup { component }
    public static func buildEither(second component: TabGroup) -> TabGroup { component }
}
