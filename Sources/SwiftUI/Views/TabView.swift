import Foundation

// MARK: - Tab Entry

/// Type-erased tab entry holding a selection value, label, and content.
public struct _AnyTabEntry {
    let value: AnyHashable
    let title: String
    let systemImage: String
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

        let selectedValue: AnyHashable = selection.map { AnyHashable($0.wrappedValue) } ?? entries[0].value

        // Build tab bar buttons with capsule style
        let tabButtons: [ViewNode] = entries.map { entry in
            let isSelected = entry.value == selectedValue
            let label = _resolve(Label(entry.title, systemImage: entry.systemImage))
            let styled: ViewNode = isSelected
                ? label.foregroundColor(.primary)
                : label.foregroundColor(.secondary)

            // Capsule background for selected tab
            let capsule: ViewNode = isSelected
                ? styled.padding(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .background(Color(white: 0.88), cornerRadius: 14)
                : styled.padding(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))

            if let selection = selection {
                let entryValue = entry.value
                let tapId = TapRegistry.shared.register {
                    if let v = entryValue.base as? SelectionValue {
                        selection.wrappedValue = v
                    }
                }
                return .onTap(id: tapId, child: capsule)
            }
            return capsule
        }

        let tabBar = ViewNode.hstack(alignment: .center, spacing: 4, children: tabButtons)

        // Register tab bar as a toolbar item (renders in the toolbar area)
        WindowState.shared.addToolbarItems(
            [ToolbarItemData(placement: .principal, node: tabBar, sourceKey: "_tabview_tabs")],
            sourceKey: "_tabview_tabs"
        )

        // Only return the selected content — tab bar is in the toolbar
        let content = entries.first(where: { $0.value == selectedValue })?.content ?? entries[0].content
        return content
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
            self.entries = nodes.enumerated().map { _AnyTabEntry(value: AnyHashable($0.offset), title: "Tab \($0.offset)", systemImage: "", content: $0.element) }
        } else {
            self.entries = [_AnyTabEntry(value: AnyHashable(0), title: "Tab", systemImage: "", content: _resolve(content()))]
        }
        self.selection = nil
    }
}

// MARK: - Tab

/// A single tab in a TabView.
/// `Value` is inferred from `TabContentBuilder<SelectionValue>`.
public struct Tab<Value: Hashable, Content: View>: TabContent {
    public typealias SelectionValue = Value
    let tabTitle: String
    let tabImage: String
    let tabValue: Value
    let child: ViewNode

    public init(_ title: String, systemImage: String, value: Value, @ViewBuilder content: () -> Content) {
        self.tabTitle = title
        self.tabImage = systemImage
        self.tabValue = value
        self.child = _resolve(content())
    }

    public var _tabEntries: [_AnyTabEntry] {
        [_AnyTabEntry(value: AnyHashable(tabValue), title: tabTitle, systemImage: tabImage, content: child)]
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
