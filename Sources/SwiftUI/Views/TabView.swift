import Foundation

// MARK: - TabContent protocol

/// Protocol for content that can appear inside a TabView.
/// Carries the `SelectionValue` type so `Tab(value: .case)` resolves correctly.
@MainActor @preconcurrency
public protocol TabContent<SelectionValue> {
    associatedtype SelectionValue: Hashable
    var _tabNodes: [ViewNode] { get }
}

// MARK: - TabView

/// A view that switches between multiple child views using a tab bar.
public struct TabView<SelectionValue: Hashable, Content>: _PrimitiveView {
    let content: [ViewNode]

    public var _nodeRepresentation: ViewNode {
        .vstack(alignment: .leading, spacing: 0, children: content)
    }
}

extension TabView where Content: TabContent<SelectionValue> {
    /// `TabView(selection:) { Tab(...) }` — typed tab content.
    public init(selection: Binding<SelectionValue>, @TabContentBuilder<SelectionValue> content: () -> Content) {
        self.content = content()._tabNodes
    }
}

extension TabView where Content: View, SelectionValue == Int {
    /// `TabView { ... }` — untyped, no selection.
    public init(@ViewBuilder content: () -> Content) {
        if let nodes = content() as? [ViewNode] { self.content = nodes }
        else { self.content = [_resolve(content())] }
    }
}

// MARK: - Tab

/// A single tab in a TabView.
/// `Value` is inferred from `TabContentBuilder<SelectionValue>`.
public struct Tab<Value: Hashable, Content: View>: TabContent {
    public typealias SelectionValue = Value
    let child: ViewNode

    public init(_ title: String, systemImage: String, value: Value, @ViewBuilder content: () -> Content) {
        self.child = _resolve(content())
    }

    public var _tabNodes: [ViewNode] { [child] }
}

extension Tab: _PrimitiveView {
    public var _nodeRepresentation: ViewNode { child }
}

extension Tab where Value == Never {
    public init(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.child = _resolve(content())
    }
}

// MARK: - TabContentBuilder

/// Result builder that propagates `SelectionValue` from `TabView(selection:)` into `Tab(value:)`.
@resultBuilder
public struct TabContentBuilder<SelectionValue: Hashable> {
    /// Wrapper that holds accumulated tab nodes.
    public struct TabGroup: TabContent {
        public let _tabNodes: [ViewNode]
    }

    // buildExpression constrains Tab's Value to match SelectionValue via bidirectional inference.
    public static func buildExpression<C: View>(_ tab: Tab<SelectionValue, C>) -> TabGroup {
        TabGroup(_tabNodes: tab._tabNodes)
    }

    public static func buildPartialBlock(first: TabGroup) -> TabGroup { first }

    public static func buildPartialBlock(accumulated: TabGroup, next: TabGroup) -> TabGroup {
        TabGroup(_tabNodes: accumulated._tabNodes + next._tabNodes)
    }

    public static func buildBlock(_ content: TabGroup) -> TabGroup { content }

    public static func buildOptional(_ component: TabGroup?) -> TabGroup {
        component ?? TabGroup(_tabNodes: [])
    }

    public static func buildEither(first component: TabGroup) -> TabGroup { component }
    public static func buildEither(second component: TabGroup) -> TabGroup { component }
}
