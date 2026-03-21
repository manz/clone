import Foundation

// MARK: - Form

/// A container for grouping controls used for data entry.
public struct Form<Content: View>: View {
    let content: [ViewNode]
    public init(@ViewBuilder content: () -> Content) {
        if let nodes = content() as? [ViewNode] { self.content = nodes }
        else { self.content = [_resolve(content())] }
    }
    public var body: ViewNode { .vstack(alignment: .leading, spacing: 8, children: content) }
}

// MARK: - SecureField

/// A text field that hides its input.
public struct SecureField: View {
    let placeholder: String
    let text: Binding<String>
    public init(_ placeholder: String, text: Binding<String>) { self.placeholder = placeholder; self.text = text }
    public var body: ViewNode { .textField(placeholder: placeholder, text: text.wrappedValue) }
}

// MARK: - TextEditor

/// A view that displays a long-form editable text interface.
public struct TextEditor: View {
    let text: Binding<String>
    public init(text: Binding<String>) { self.text = text }
    public var body: ViewNode { .textField(placeholder: "", text: text.wrappedValue) }
}

// MARK: - Stepper

/// A control for incrementing or decrementing a value.
public struct Stepper<Label: View>: View {
    let label: ViewNode
    public init(value: Binding<Int>, in range: ClosedRange<Int> = 0...100, step: Int = 1, @ViewBuilder label: () -> Label) {
        self.label = _resolve(label())
    }
    public init(value: Binding<Double>, in range: ClosedRange<Double> = 0...100, step: Double = 1, @ViewBuilder label: () -> Label) {
        self.label = _resolve(label())
    }
    public var body: ViewNode { label }
}

extension Stepper where Label == Text {
    public init(_ title: String, value: Binding<Int>, in range: ClosedRange<Int> = 0...100, step: Int = 1) {
        self.label = Text(title).body
    }
    public init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double> = 0...100, step: Double = 1) {
        self.label = Text(title).body
    }
}

// MARK: - Link

/// A control for navigating to a URL.
public struct Link<Label: View>: View {
    let label: ViewNode
    public init(destination: URL, @ViewBuilder label: () -> Label) { self.label = _resolve(label()) }
    public var body: ViewNode { label }
}

extension Link where Label == Text {
    public init(_ title: String, destination: URL) { self.label = Text(title).body }
}

// MARK: - LabeledContent

/// A container for attaching a label to a value-bearing view.
public struct LabeledContent<Label: View, Content: View>: View {
    let label: ViewNode
    let content: ViewNode
    public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.label = _resolve(label())
        self.content = _resolve(content())
    }
    public var body: ViewNode { .hstack(alignment: .center, spacing: 8, children: [label, .spacer(minLength: 0), content]) }
}

extension LabeledContent where Label == Text {
    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.label = Text(title).body
        self.content = _resolve(content())
    }
}

extension LabeledContent where Label == Text, Content == Text {
    public init(_ title: String, value: String) {
        self.label = Text(title).body
        self.content = Text(value).body
    }
}

// MARK: - ContentUnavailableView

/// A view that indicates content is unavailable.
public struct ContentUnavailableView<Label: View, Description: View, Actions: View>: View {
    let label: ViewNode
    public var body: ViewNode { label }
}

extension ContentUnavailableView where Label == ViewNode, Description == ViewNode, Actions == ViewNode {
    public init(_ title: String, systemImage: String, description: Text? = nil) {
        self.label = ViewNode.vstack(alignment: .center, spacing: 8, children: [
            Image(systemName: systemImage).body,
            Text(title).body,
        ])
    }
}

extension ContentUnavailableView where Actions == EmptyView {
    /// `ContentUnavailableView { label } description: { text }` — multi-trailing-closure.
    public init(@ViewBuilder label: () -> Label, @ViewBuilder description: () -> Description) {
        self.label = ViewNode.vstack(alignment: .center, spacing: 8, children: [
            _resolve(label()),
            _resolve(description()),
        ])
    }

    /// `ContentUnavailableView { label } description: { text } actions: { buttons }` — full form.
    public init(@ViewBuilder label: () -> Label, @ViewBuilder description: () -> Description, @ViewBuilder actions: () -> Actions) {
        self.label = ViewNode.vstack(alignment: .center, spacing: 8, children: [
            _resolve(label()),
            _resolve(description()),
            _resolve(actions()),
        ])
    }
}

// MARK: - LazyVStack / LazyHStack

/// A lazy vertical stack. On Clone, renders as a regular VStack.
public struct LazyVStack: View {
    let content: [ViewNode]
    public init(alignment: HAlignment = .center, spacing: CGFloat? = nil, pinnedViews: Swift.Set<PinnedScrollableViews> = [], @ViewBuilder content: () -> [ViewNode]) {
        self.content = content()
    }
    public var body: ViewNode { .vstack(alignment: .leading, spacing: 8, children: content) }
}

/// A lazy horizontal stack. On Clone, renders as a regular HStack.
public struct LazyHStack: View {
    let content: [ViewNode]
    public init(alignment: VAlignment = .center, spacing: CGFloat? = nil, pinnedViews: Swift.Set<PinnedScrollableViews> = [], @ViewBuilder content: () -> [ViewNode]) {
        self.content = content()
    }
    public var body: ViewNode { .hstack(alignment: .center, spacing: 8, children: content) }
}

// MARK: - ScrollViewReader / ScrollViewProxy

/// A view whose child is defined as a function of a scroll view proxy.
public struct ScrollViewReader<Content: View>: View {
    let content: (ScrollViewProxy) -> Content
    public init(@ViewBuilder content: @escaping (ScrollViewProxy) -> Content) { self.content = content }
    public var body: ViewNode { _resolve(content(ScrollViewProxy())) }
}

/// A proxy value that supports programmatic scrolling.
public struct ScrollViewProxy {
    public func scrollTo<ID: Hashable>(_ id: ID, anchor: UnitPoint? = nil) {}
}

// MARK: - NavigationView (deprecated but still used)

/// A deprecated view for presenting a stack of views.
public struct NavigationView<Content: View>: View {
    let content: ViewNode
    public init(@ViewBuilder content: () -> Content) { self.content = _resolve(content()) }
    public var body: ViewNode { content }
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
public struct Table<Value, Rows, Columns>: View {
    public var body: ViewNode { .empty }
}

extension Table where Rows == Never, Columns == Never {
    public init<Data: RandomAccessCollection>(_ data: Data, @ViewBuilder columns: () -> [ViewNode]) where Data.Element == Value {
        // stub
    }

    public init<Data: RandomAccessCollection, SelectionValue: Hashable>(_ data: Data, selection: Binding<Set<SelectionValue>>, @ViewBuilder columns: () -> [ViewNode]) where Data.Element == Value {
        // stub
    }

    public init<Data: RandomAccessCollection, SelectionValue: Hashable>(_ data: Data, selection: Binding<SelectionValue?>, @ViewBuilder columns: () -> [ViewNode]) where Data.Element == Value {
        // stub
    }
}

/// A column in a table.
public struct TableColumn<RowValue, Sort, Content: View, Label: View>: View {
    public var body: ViewNode { .empty }
}

extension TableColumn where Content == Text, Label == Text, Sort == Never {
    public init(_ title: String, value: KeyPath<RowValue, String>) {}
    public init(_ title: String, @ViewBuilder content: @escaping (RowValue) -> Content) {}
}

extension TableColumn where Label == Text, Sort == Never {
    public init(_ title: String, @ViewBuilder content: @escaping (RowValue) -> Content) {}
}

// MARK: - ToolbarItem

/// A model that represents an item in a toolbar.
public struct ToolbarItem<ID, Content: View>: View {
    let content: ViewNode
    public var body: ViewNode { content }
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
}

/// A protocol for toolbar content.
@MainActor
public protocol ToolbarContent {
    associatedtype Body: View
    var body: Body { get }
}

/// Make [ViewNode] conform to ToolbarContent so @ToolbarContentBuilder works.
extension Array: ToolbarContent where Element == ViewNode {}

/// Kind of default toolbar item that can be removed.
public struct ToolbarDefaultItemKind: Sendable {
    public static let sidebarToggle = ToolbarDefaultItemKind()
}

/// A result builder for toolbar content.
@resultBuilder
public struct ToolbarContentBuilder {
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
public struct CommandGroup<Content: View>: Commands, View {
    public init(replacing: CommandGroupPlacement, @ViewBuilder content: () -> Content) {}
    public init(after: CommandGroupPlacement, @ViewBuilder content: () -> Content) {}
    public init(before: CommandGroupPlacement, @ViewBuilder content: () -> Content) {}
    public var body: ViewNode { .empty }
}

/// A custom command menu.
public struct CommandMenu<Content: View>: Commands, View {
    public init(_ name: String, @ViewBuilder content: () -> Content) {}
    public var body: ViewNode { .empty }
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
public protocol NSViewRepresentable: View {
    associatedtype NSViewType: NSView
    func makeNSView(context: Context) -> NSViewType
    func updateNSView(_ nsView: NSViewType, context: Context)

    typealias Context = NSViewRepresentableContext<Self>
}

/// Context for an NSViewRepresentable.
public struct NSViewRepresentableContext<Representable> {
    public var environment: EnvironmentValues { EnvironmentValues() }
}

extension NSViewRepresentable {
    public var body: ViewNode { .empty }
}

