import Foundation

// MARK: - Form

/// A container for grouping controls used for data entry.
public struct Form<Content: View>: _PrimitiveView {
    let content: [ViewNode]
    public init(@ViewBuilder content: () -> Content) {
        if let nodes = content() as? [ViewNode] { self.content = nodes }
        else { self.content = [_resolve(content())] }
    }
    public var _nodeRepresentation: ViewNode { .vstack(alignment: .leading, spacing: 8, children: content) }
}

// MARK: - SecureField

/// A text field that hides its input.
public struct SecureField: _PrimitiveView {
    let placeholder: String
    let text: Binding<String>
    public init(_ placeholder: String, text: Binding<String>) { self.placeholder = placeholder; self.text = text }
    public var _nodeRepresentation: ViewNode { .textField(placeholder: placeholder, text: text.wrappedValue) }
}

// MARK: - TextEditor

/// A view that displays a long-form editable text interface.
public struct TextEditor: _PrimitiveView {
    let text: Binding<String>
    public init(text: Binding<String>) { self.text = text }
    public var _nodeRepresentation: ViewNode { .textField(placeholder: "", text: text.wrappedValue) }
}

// MARK: - Stepper

/// A control for incrementing or decrementing a value.
public struct Stepper<Label: View>: _PrimitiveView {
    let label: ViewNode
    public init(value: Binding<Int>, in range: ClosedRange<Int> = 0...100, step: Int = 1, @ViewBuilder label: () -> Label) {
        self.label = _resolve(_flattenToNodes(label()))
    }
    public init(value: Binding<Double>, in range: ClosedRange<Double> = 0...100, step: Double = 1, @ViewBuilder label: () -> Label) {
        self.label = _resolve(_flattenToNodes(label()))
    }
    public init(value: Binding<Int>, in range: PartialRangeFrom<Int>, step: Int = 1, @ViewBuilder label: () -> Label) {
        self.label = _resolve(_flattenToNodes(label()))
    }
    public init(value: Binding<Double>, in range: PartialRangeFrom<Double>, step: Double = 1, @ViewBuilder label: () -> Label) {
        self.label = _resolve(_flattenToNodes(label()))
    }
    public var _nodeRepresentation: ViewNode { label }
}

extension Stepper where Label == Text {
    public init(_ title: String, value: Binding<Int>, in range: ClosedRange<Int> = 0...100, step: Int = 1) {
        self.label = _resolve(Text(title))
    }
    public init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double> = 0...100, step: Double = 1) {
        self.label = _resolve(Text(title))
    }
    public init(_ title: String, value: Binding<Int>, in range: PartialRangeFrom<Int>, step: Int = 1) {
        self.label = _resolve(Text(title))
    }
    public init(_ title: String, value: Binding<Double>, in range: PartialRangeFrom<Double>, step: Double = 1) {
        self.label = _resolve(Text(title))
    }
}

// MARK: - Link

/// A control for navigating to a URL.
public struct Link<Label: View>: _PrimitiveView {
    let label: ViewNode
    public init(destination: URL, @ViewBuilder label: () -> Label) { self.label = _resolve(_flattenToNodes(label())) }
    public var _nodeRepresentation: ViewNode { label }
}

extension Link where Label == Text {
    public init(_ title: String, destination: URL) { self.label = _resolve(Text(title)) }
}

// MARK: - LabeledContent

/// A container for attaching a label to a value-bearing view.
public struct LabeledContent<Label: View, Content: View>: _PrimitiveView {
    let label: ViewNode
    let content: ViewNode
    public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.label = _resolve(_flattenToNodes(label()))
        self.content = _resolve(content())
    }
    public var _nodeRepresentation: ViewNode { .hstack(alignment: .center, spacing: 8, children: [label, .spacer(minLength: 0), content]) }
}

extension LabeledContent where Label == Text {
    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.label = _resolve(Text(title))
        self.content = _resolve(content())
    }
}

extension LabeledContent where Label == Text, Content == Text {
    public init(_ title: String, value: String) {
        self.label = _resolve(Text(title))
        self.content = _resolve(Text(value))
    }
}

// MARK: - ContentUnavailableView

/// A view that indicates content is unavailable.
public struct ContentUnavailableView<Label: View, Description: View, Actions: View>: _PrimitiveView {
    let label: ViewNode
    public var _nodeRepresentation: ViewNode { label }
}

extension ContentUnavailableView where Label == ViewNode, Description == ViewNode, Actions == ViewNode {
    public init(_ title: String, systemImage: String, description: Text? = nil) {
        self.label = ViewNode.vstack(alignment: .center, spacing: 8, children: [
            _resolve(Image(systemName: systemImage)),
            _resolve(Text(title)),
        ])
    }
}

extension ContentUnavailableView where Actions == EmptyView {
    /// `ContentUnavailableView { label } description: { text }` — multi-trailing-closure.
    public init(@ViewBuilder label: () -> Label, @ViewBuilder description: () -> Description) {
        self.label = ViewNode.vstack(alignment: .center, spacing: 8, children: [
            _resolve(_flattenToNodes(label())),
            _resolve(description()),
        ])
    }

    /// `ContentUnavailableView { label } description: { text } actions: { buttons }` — full form.
    public init(@ViewBuilder label: () -> Label, @ViewBuilder description: () -> Description, @ViewBuilder actions: () -> Actions) {
        self.label = ViewNode.vstack(alignment: .center, spacing: 8, children: [
            _resolve(_flattenToNodes(label())),
            _resolve(description()),
            _resolve(actions()),
        ])
    }
}

// MARK: - LazyVStack / LazyHStack

/// A lazy vertical stack. On Clone, renders as a regular VStack.
public struct LazyVStack: _PrimitiveView {
    let content: [ViewNode]
    public init(alignment: HAlignment = .center, spacing: CGFloat? = nil, pinnedViews: Swift.Set<PinnedScrollableViews> = [], @ViewBuilder content: () -> some View) {
        self.content = _flattenToNodes(content())
    }
    public var _nodeRepresentation: ViewNode { .vstack(alignment: .leading, spacing: 8, children: content) }
}

/// A lazy horizontal stack. On Clone, renders as a regular HStack.
public struct LazyHStack: _PrimitiveView {
    let content: [ViewNode]
    public init(alignment: VAlignment = .center, spacing: CGFloat? = nil, pinnedViews: Swift.Set<PinnedScrollableViews> = [], @ViewBuilder content: () -> some View) {
        self.content = _flattenToNodes(content())
    }
    public var _nodeRepresentation: ViewNode { .hstack(alignment: .center, spacing: 8, children: content) }
}

// MARK: - ScrollViewReader / ScrollViewProxy

/// A view whose child is defined as a function of a scroll view proxy.
public struct ScrollViewReader<Content: View>: _PrimitiveView {
    let content: (ScrollViewProxy) -> Content
    public init(@ViewBuilder content: @escaping (ScrollViewProxy) -> Content) { self.content = content }
    public var _nodeRepresentation: ViewNode { _resolve(content(ScrollViewProxy())) }
}

/// A proxy value that supports programmatic scrolling.
public struct ScrollViewProxy {
    public func scrollTo<ID: Hashable>(_ id: ID, anchor: UnitPoint? = nil) {}
}

// MARK: - NavigationView (deprecated but still used)

/// A deprecated view for presenting a stack of views.
public struct NavigationView<Content: View>: _PrimitiveView {
    let content: ViewNode
    public init(@ViewBuilder content: () -> Content) { self.content = _resolve(content()) }
    public var _nodeRepresentation: ViewNode { content }
}

// MARK: - NavigationPath

/// A type-erased list of navigation destinations.
public struct NavigationPath {
    public var count: Int { 0 }
    public var isEmpty: Bool { true }
    public init() {}
    public mutating func append<V: Hashable>(_ value: V) {}
    public mutating func removeLast(_ k: Int = 1) {}
}

// MARK: - Table (stub)

/// A container that presents rows of data in columns.
public struct Table<Value, Rows, Columns>: _PrimitiveView {
    public var _nodeRepresentation: ViewNode { .empty }
}

extension Table where Rows == Never {
    public init<Data: RandomAccessCollection>(_ data: Data, @TableColumnBuilder<Value, Never> columns: () -> Columns) where Data.Element == Value {
        // stub
    }

    public init<Data: RandomAccessCollection, SelectionValue: Hashable>(_ data: Data, selection: Binding<Set<SelectionValue>>, @TableColumnBuilder<Value, Never> columns: () -> Columns) where Data.Element == Value {
        // stub
    }

    public init<Data: RandomAccessCollection, SelectionValue: Hashable>(_ data: Data, selection: Binding<SelectionValue?>, @TableColumnBuilder<Value, Never> columns: () -> Columns) where Data.Element == Value {
        // stub
    }
}

/// Result builder for table columns — type-preserving like ViewBuilder.
@resultBuilder
public struct TableColumnBuilder<RowValue, Sort> {
    public static func buildExpression<Content: View, Label: View>(_ expression: TableColumn<RowValue, Sort, Content, Label>) -> TableColumn<RowValue, Sort, Content, Label> { expression }
    public static func buildExpression<C: View>(_ expression: C) -> C { expression }
    public static func buildBlock<C: View>(_ content: C) -> C { content }
    public static func buildBlock<C0: View, C1: View>(_ c0: C0, _ c1: C1) -> TupleView<(C0, C1)> { TupleView((c0, c1)) }
    public static func buildBlock<C0: View, C1: View, C2: View>(_ c0: C0, _ c1: C1, _ c2: C2) -> TupleView<(C0, C1, C2)> { TupleView((c0, c1, c2)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> TupleView<(C0, C1, C2, C3)> { TupleView((c0, c1, c2, c3)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4) -> TupleView<(C0, C1, C2, C3, C4)> { TupleView((c0, c1, c2, c3, c4)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5) -> TupleView<(C0, C1, C2, C3, C4, C5)> { TupleView((c0, c1, c2, c3, c4, c5)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6) -> TupleView<(C0, C1, C2, C3, C4, C5, C6)> { TupleView((c0, c1, c2, c3, c4, c5, c6)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7) -> TupleView<(C0, C1, C2, C3, C4, C5, C6, C7)> { TupleView((c0, c1, c2, c3, c4, c5, c6, c7)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View, C8: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8) -> TupleView<(C0, C1, C2, C3, C4, C5, C6, C7, C8)> { TupleView((c0, c1, c2, c3, c4, c5, c6, c7, c8)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View, C8: View, C9: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9) -> TupleView<(C0, C1, C2, C3, C4, C5, C6, C7, C8, C9)> { TupleView((c0, c1, c2, c3, c4, c5, c6, c7, c8, c9)) }
    public static func buildOptional<C: View>(_ component: C?) -> C? { component }
    public static func buildEither<T: View, F: View>(first: T) -> _ConditionalContent<T, F> { .trueContent(first) }
    public static func buildEither<T: View, F: View>(second: F) -> _ConditionalContent<T, F> { .falseContent(second) }
    public static func buildOptional(_ component: [ViewNode]?) -> [ViewNode] { component ?? [] }
    public static func buildEither(first component: [ViewNode]) -> [ViewNode] { component }
    public static func buildEither(second component: [ViewNode]) -> [ViewNode] { component }
}

/// A column in a table.
public struct TableColumn<RowValue, Sort, Content: View, Label: View>: _PrimitiveView {
    public var _nodeRepresentation: ViewNode { .empty }
}

extension TableColumn where Content == Text, Label == Text, Sort == Never {
    public init(_ title: String, value: KeyPath<RowValue, String>) {}
    public init(_ title: String, @ViewBuilder content: @escaping (RowValue) -> Content) {}
}

extension TableColumn where Label == Text, Sort == Never {
    public init(_ title: String, @ViewBuilder content: @escaping (RowValue) -> Content) {}
}

extension TableColumn {
    /// `.width(_:)` — sets column width. No-op on Clone.
    public func width(_ width: CGFloat? = nil) -> TableColumn { self }
    /// `.width(min:ideal:max:)` — sets column width range. No-op on Clone.
    public func width(min: CGFloat? = nil, ideal: CGFloat? = nil, max: CGFloat? = nil) -> TableColumn { self }
}

// MARK: - ToolbarItem

/// A model that represents an item in a toolbar.
public struct ToolbarItem<ID, Content: View>: _PrimitiveView {
    let content: ViewNode
    public var _nodeRepresentation: ViewNode { content }
}

extension ToolbarItem where ID == Void {
    public init(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> Content) {
        self.content = _resolve(content())
    }
}

extension ToolbarItem: ToolbarContent {}

/// The placement of a toolbar item.
public struct ToolbarItemPlacement: Sendable {
    public static let automatic = ToolbarItemPlacement()
    public static let navigation = ToolbarItemPlacement()
    public static let primaryAction = ToolbarItemPlacement()
    public static let cancellationAction = ToolbarItemPlacement()
    public static let confirmationAction = ToolbarItemPlacement()
    public static let destructiveAction = ToolbarItemPlacement()
    public static let status = ToolbarItemPlacement()
    public static let navigationBarLeading = ToolbarItemPlacement()
    public static let navigationBarTrailing = ToolbarItemPlacement()
    public static let bottomBar = ToolbarItemPlacement()
    public static let keyboard = ToolbarItemPlacement()
    public static let topBarLeading = ToolbarItemPlacement()
    public static let topBarTrailing = ToolbarItemPlacement()
    public static let principal = ToolbarItemPlacement()
    public static let search = ToolbarItemPlacement()
    public static let sidebarToggle = ToolbarItemPlacement()
    public static let secondaryAction = ToolbarItemPlacement()
}

/// A protocol for toolbar content.
@MainActor
public protocol ToolbarContent: View {}

/// Make [ViewNode] conform to ToolbarContent so @ToolbarContentBuilder works.
extension Array: ToolbarContent where Element == ViewNode {}

/// Kind of default toolbar item that can be removed.
public struct ToolbarDefaultItemKind: Sendable {
    public static let sidebarToggle = ToolbarDefaultItemKind()
}

/// A result builder for toolbar content.
@resultBuilder
public struct ToolbarContentBuilder {
    public static func buildBlock() -> [ViewNode] { [] }
    public static func buildBlock<C: View>(_ content: C) -> C { content }
    public static func buildBlock(_ components: [ViewNode]...) -> [ViewNode] { components.flatMap { $0 } }
    @MainActor public static func buildExpression<V: View>(_ expression: V) -> [ViewNode] { [_resolve(expression)] }
    public static func buildOptional(_ component: [ViewNode]?) -> [ViewNode] { component ?? [] }
    public static func buildEither(first component: [ViewNode]) -> [ViewNode] { component }
    public static func buildEither(second component: [ViewNode]) -> [ViewNode] { component }
}

// MARK: - Commands

/// A protocol for defining app commands.
public protocol Commands {}

/// A group of commands that replaces or augments an existing command group.
public struct CommandGroup<Content: View>: Commands, _PrimitiveView {
    public init(replacing: CommandGroupPlacement, @ViewBuilder content: () -> Content) {}
    public init(after: CommandGroupPlacement, @ViewBuilder content: () -> Content) {}
    public init(before: CommandGroupPlacement, @ViewBuilder content: () -> Content) {}
    public var _nodeRepresentation: ViewNode { .empty }
}

/// A custom command menu.
public struct CommandMenu<Content: View>: Commands, _PrimitiveView {
    public init(_ name: String, @ViewBuilder content: () -> Content) {}
    public var _nodeRepresentation: ViewNode { .empty }
}

/// The placement of a command group.
public struct CommandGroupPlacement: Sendable {
    public static let appInfo = CommandGroupPlacement()
    public static let appSettings = CommandGroupPlacement()
    public static let appTermination = CommandGroupPlacement()
    public static let appVisibility = CommandGroupPlacement()
    public static let newItem = CommandGroupPlacement()
    public static let pasteboard = CommandGroupPlacement()
    public static let saveItem = CommandGroupPlacement()
    public static let sidebar = CommandGroupPlacement()
    public static let systemServices = CommandGroupPlacement()
    public static let textEditing = CommandGroupPlacement()
    public static let textFormatting = CommandGroupPlacement()
    public static let undoRedo = CommandGroupPlacement()
    public static let windowArrangement = CommandGroupPlacement()
    public static let windowList = CommandGroupPlacement()
    public static let windowSize = CommandGroupPlacement()
    public static let importExport = CommandGroupPlacement()
    public static let printItem = CommandGroupPlacement()
    public static let help = CommandGroupPlacement()
    public static let toolbar = CommandGroupPlacement()
}

// MARK: - NSViewRepresentable

/// A wrapper that you use to integrate an AppKit view into your view hierarchy.
@MainActor @preconcurrency
public protocol NSViewRepresentable: _PrimitiveView {
    associatedtype NSViewType
    @MainActor func makeNSView(context: Context) -> NSViewType
    @MainActor func updateNSView(_ nsView: NSViewType, context: Context)

    typealias Context = NSViewRepresentableContext<Self>
}

/// Context for an NSViewRepresentable — includes coordinator support.
public struct NSViewRepresentableContext<Representable> {
    public var environment: EnvironmentValues { EnvironmentValues() }
    public var coordinator: Any { () }
}

extension NSViewRepresentable {
    public var _nodeRepresentation: ViewNode { .empty }
}

// MARK: - GroupBox

/// A bordered container for grouping related controls.
public struct GroupBox<Label: View, Content: View>: _PrimitiveView {
    let label: ViewNode
    let content: ViewNode
    public init(@ViewBuilder content: () -> Content) where Label == EmptyView {
        self.label = .empty
        self.content = _resolve(content())
    }
    public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.label = _resolve(label())
        self.content = _resolve(content())
    }
    public var _nodeRepresentation: ViewNode {
        .vstack(alignment: .leading, spacing: 8, children: [label, content])
    }
}

extension GroupBox where Label == Text {
    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.label = _resolve(Text(title).bold())
        self.content = _resolve(content())
    }
}

// MARK: - DatePickerComponents

public struct DatePickerComponents: OptionSet, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public static let date = DatePickerComponents(rawValue: 1 << 0)
    public static let hourAndMinute = DatePickerComponents(rawValue: 1 << 1)
}

// MARK: - DatePicker

/// A control for selecting dates. Stub on Clone.
public struct DatePicker<Label: View>: _PrimitiveView {
    let label: ViewNode
    public init(selection: Binding<Date>, displayedComponents: DatePicker.Components = .date, @ViewBuilder label: () -> Label) {
        self.label = _resolve(label())
    }
    public var _nodeRepresentation: ViewNode { label }
    public typealias Components = DatePickerComponents
}

extension DatePicker where Label == Text {
    public init(_ title: String, selection: Binding<Date>, displayedComponents: DatePicker.Components = .date) {
        self.label = _resolve(Text(title))
    }
}

// MARK: - ToolbarItemGroup

/// Groups multiple toolbar items together.
public struct ToolbarItemGroup<Content: View>: _PrimitiveView, ToolbarContent {
    let content: ViewNode
    public init(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> Content) {
        self.content = _resolve(content())
    }
    public var _nodeRepresentation: ViewNode { content }
}

