// Re-export Foundation so `import SwiftUI` brings in Foundation types (URL, Date, CGFloat, etc.)
// This matches Apple's SwiftUI behavior.
@_exported import Foundation
@_exported import AppKit
#if canImport(UniformTypeIdentifiers)
@_exported import UniformTypeIdentifiers
#endif

/// The core protocol for SwiftUI views — matches Apple's SwiftUI.
@preconcurrency @MainActor
public protocol View {
    associatedtype Body: View
    @ViewBuilder var body: Body { get }
}

/// Never as terminal View — required for @ViewBuilder on protocol.
extension Never: View {
    public typealias Body = Never
    public var body: Never { fatalError() }
}

// MARK: - _PrimitiveView

/// Protocol for framework-internal views that resolve directly to ViewNode.
/// Body is Never so @ViewBuilder is harmless (fatalError() → Never bypasses result builder).
public protocol _PrimitiveView: View where Body == Never {
    var _nodeRepresentation: ViewNode { get }
}

extension _PrimitiveView {
    public var body: Never { fatalError() }
}

/// ViewNode is the terminal primitive.
extension ViewNode: _PrimitiveView {
    public var _nodeRepresentation: ViewNode { self }
}

/// [ViewNode] as a View.
extension Array: View where Element == ViewNode {
    public typealias Body = Never
    public var body: Never { fatalError() }
}
extension Array: _PrimitiveView where Element == ViewNode {
    public var _nodeRepresentation: ViewNode {
        if count == 1 { return self[0] }
        return .vstack(alignment: .leading, spacing: 0, children: self)
    }
}

/// Color as a View.
extension Color: _PrimitiveView {
    public var _nodeRepresentation: ViewNode {
        .rect(width: nil, height: nil, fill: self)
    }
}

// MARK: - View → ViewNode materialization

/// Resolves any View to its terminal ViewNode.
/// Checks _PrimitiveView first to avoid calling body on Never-bodied types.
func _resolve<V: View>(_ view: V) -> ViewNode {
    if let primitive = view as? _PrimitiveView { return primitive._nodeRepresentation }
    if let node = view as? ViewNode { return node }
    return _resolve(view.body)
}

// MARK: - AttributedString SwiftUI extensions

extension AttributedString {
    /// SwiftUI foregroundColor on AttributedString — matches Apple's SwiftUI.
    public var foregroundColor: Color? {
        get { nil }
        set { /* no-op on Clone */ }
    }

    /// SwiftUI strikethroughStyle on AttributedString.
    public var strikethroughStyle: Text.LineStyle? {
        get { nil }
        set { /* no-op on Clone */ }
    }
}

extension Text {
    /// Line style for strikethrough/underline.
    public struct LineStyle: Sendable {
        public static let single = LineStyle()
        public init() {}
    }
}

// MARK: - Modified View wrapper

/// Opaque wrapper for modifier chains. Hides ViewNode from the public API surface.
public struct _ModifiedView<Content: View>: _PrimitiveView {
    @usableFromInline let node: ViewNode
    public var _nodeRepresentation: ViewNode { node }
    @usableFromInline init(node: ViewNode) { self.node = node }
}

// MARK: - Modifier extensions on View

/// Modifiers return `_ModifiedView<Self>` to keep View types distinct across branches.
public extension View {

    func frame(width: CGFloat? = nil, height: CGFloat? = nil) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).frame(width: width, height: height))
    }

    func frame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).frame(width: width, height: height))
    }

    func frame(maxWidth: CGFloat? = nil, maxHeight: CGFloat? = nil) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).frame(maxWidth: maxWidth, maxHeight: maxHeight))
    }

    func frame(maxWidth: CGFloat? = nil, maxHeight: CGFloat? = nil, alignment: Alignment) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).frame(maxWidth: maxWidth, maxHeight: maxHeight))
    }

    func frame(minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil, minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil, maxHeight: CGFloat? = nil, alignment: Alignment = .center) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).frame(minWidth: minWidth, idealWidth: idealWidth, maxWidth: maxWidth, minHeight: minHeight, idealHeight: idealHeight, maxHeight: maxHeight, alignment: alignment))
    }

    func padding(_ value: CGFloat) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).padding(value))
    }

    func padding(_ edges: Edge.Set) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).padding(edges))
    }

    func padding(_ edges: Edge.Set, _ value: CGFloat) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).padding(edges, value))
    }

    func padding() -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).padding())
    }

    func padding(_ insets: EdgeInsets) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).padding(insets))
    }

    func opacity(_ value: CGFloat) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).opacity(value))
    }

    func foregroundColor(_ color: Color) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).foregroundColor(color))
    }

    func font(_ font: Font) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).font(font))
    }

    func bold() -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).bold())
    }

    func italic() -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).italic())
    }

    func fontWeight(_ weight: Font.Weight) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).fontWeight(weight))
    }

    func fill(_ color: Color) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).fill(color))
    }

    func fill<S: View>(_ style: S) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).fill(style))
    }

    func cornerRadius(_ radius: CGFloat) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).cornerRadius(radius))
    }

    func shadow(
        color: Color = Color(r: 0, g: 0, b: 0, a: 0.3),
        radius: CGFloat = 10,
        x: CGFloat = 0,
        y: CGFloat = 2
    ) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).shadow(color: color, radius: radius, x: x, y: y))
    }

    func onTapGesture(_ handler: @escaping () -> Void) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).onTapGesture(handler))
    }

    func onTapGesture(count: Int = 1, perform handler: @escaping () -> Void) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).onTapGesture(count: count, perform: handler))
    }

    func onTapGesture(count: Int = 1, coordinateSpace: CoordinateSpace = .local, perform handler: @escaping (CGPoint) -> Void) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).onTapGesture(count: count, coordinateSpace: coordinateSpace, perform: handler))
    }

    func onHover(_ handler: @escaping (Bool) -> Void) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).onHover(handler))
    }

    func onContinuousHover(_ handler: @escaping (HoverPhase) -> Void) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).onContinuousHover(handler))
    }

    func clipped(radius: CGFloat = 0) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).clipped(radius: radius))
    }

    func navigationTitle(_ title: String) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).navigationTitle(title))
    }

    func background(_ color: Color) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).background(color))
    }

    func contentShape<S: View>(_ shape: S) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func overlay(@ViewBuilder content: () -> some View) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).overlay(content: content))
    }

    func overlay(alignment: Alignment = .center, @ViewBuilder content: () -> some View) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).overlay(alignment: alignment, content: content))
    }

    func overlay<V: View>(_ overlay: V) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).overlay(overlay))
    }

    func overlay<V: View>(_ overlay: V, alignment: Alignment) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).overlay(overlay))
    }

    func disabled(_ isDisabled: Bool) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).disabled(isDisabled))
    }

    func tint(_ color: Color?) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).tint(color))
    }

    func onAppear(perform action: (() -> Void)? = nil) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).onAppear(perform: action))
    }

    func onDisappear(perform action: (() -> Void)? = nil) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).onDisappear(perform: action))
    }

    func task(priority: TaskPriority = .userInitiated, _ action: @escaping @MainActor @Sendable () async -> Void) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).task(priority: priority, action))
    }

    func task<T: Equatable>(id: T, priority: TaskPriority = .userInitiated, _ action: @escaping @MainActor @Sendable () async -> Void) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).task(id: id, priority: priority, action))
    }

    func sheet(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: () -> some View) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).sheet(isPresented: isPresented, onDismiss: onDismiss, content: content))
    }

    func sheet<Item>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> some View) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).sheet(item: item, onDismiss: onDismiss, content: content))
    }

    func alert(_ title: String, isPresented: Binding<Bool>, @ViewBuilder actions: () -> some View) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).alert(title, isPresented: isPresented, actions: actions))
    }

    func alert(_ title: String, isPresented: Binding<Bool>, @ViewBuilder actions: () -> some View, @ViewBuilder message: () -> some View) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).alert(title, isPresented: isPresented, actions: actions, message: message))
    }

    func confirmationDialog(_ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> some View) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).confirmationDialog(title, isPresented: isPresented, titleVisibility: titleVisibility, actions: actions))
    }

    func confirmationDialog(_ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> some View, @ViewBuilder message: () -> some View) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).confirmationDialog(title, isPresented: isPresented, titleVisibility: titleVisibility, actions: actions, message: message))
    }

    func searchable(text: Binding<String>, isPresented: Binding<Bool>, placement: Any? = nil, prompt: String? = nil) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).searchable(text: text, isPresented: isPresented, placement: placement, prompt: prompt))
    }

    func searchable(text: Binding<String>, isPresented: Binding<Bool> = .constant(false), isSearchFieldFocused: Binding<Bool>, placement: Any? = nil, prompt: String? = nil) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).searchable(text: text, isPresented: isPresented, isSearchFieldFocused: isSearchFieldFocused, placement: placement, prompt: prompt))
    }

    func searchable(text: Binding<String>, placement: Any? = nil, prompt: String? = nil) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).searchable(text: text, placement: placement, prompt: prompt))
    }

    func onChange<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).onChange(of: value, perform: action))
    }

    func onChange<V: Equatable>(of value: V, initial: Bool = false, _ action: @escaping () -> Void) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).onChange(of: value, initial: initial, action))
    }

    func animation(_ animation: Animation?) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).animation(animation))
    }

    func animation<V: Equatable>(_ animation: Animation?, value: V) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).animation(animation, value: value))
    }

    func transition(_ t: AnyTransition) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).transition(t))
    }

    func tabItem(@ViewBuilder content: () -> some View) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).tabItem(content: content))
    }

    func tag<V: Hashable>(_ tag: V) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).tag(tag))
    }

    func ignoresSafeArea(_ regions: Any?...) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func safeAreaInset(edge: Edge.Set, @ViewBuilder content: () -> some View) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).safeAreaInset(edge: edge, content: content))
    }

    func safeAreaInset(edge: VerticalEdge, alignment: HAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> some View) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func safeAreaInset(edge: HorizontalEdge, alignment: VAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> some View) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func lineLimit(_ limit: Int?) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).lineLimit(limit))
    }

    func lineLimit(_ range: PartialRangeFrom<Int>) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func lineLimit(_ range: ClosedRange<Int>) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func multilineTextAlignment(_ alignment: TextAlignment) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).multilineTextAlignment(alignment))
    }

    func textFieldStyle<S: TextFieldStyle>(_ style: S) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).textFieldStyle(style))
    }

    func buttonStyle<S: ButtonStyle>(_ style: S) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).buttonStyle(style))
    }

    func listStyle<S: ListStyle>(_ style: S) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).listStyle(style))
    }

    func pickerStyle<S: PickerStyle>(_ style: S) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).pickerStyle(style))
    }

    func toggleStyle<S: ToggleStyle>(_ style: S) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).toggleStyle(style))
    }

    func foregroundStyle(_ color: Color) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).foregroundStyle(color))
    }

    func foregroundStyle<S: View>(_ style: S) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).foregroundStyle(style))
    }

    func foregroundStyle(_ primary: Color, _ secondary: Color) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).foregroundStyle(primary, secondary))
    }

    func foregroundStyle(_ primary: Color, _ secondary: Color, _ tertiary: Color) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).foregroundStyle(primary, secondary, tertiary))
    }

    func foregroundStyle<S1: View, S2: View>(_ primary: S1, _ secondary: S2) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).foregroundStyle(primary, secondary))
    }

    func foregroundStyle<S: ShapeStyle>(_ style: S) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func background<S: View>(_ color: Color, in shape: S) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).background(color, in: shape))
    }

    func background<V: View>(_ view: V) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).background(view))
    }

    func background(@ViewBuilder content: () -> some View) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).background(content: content))
    }

    func background(alignment: HAlignment = .center, @ViewBuilder content: () -> some View) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).background(alignment: alignment, content: content))
    }

    func help(_ text: String) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func accessibilityLabel(_ label: String) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func accessibilityHidden(_ hidden: Bool) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func focusable(_ isFocusable: Bool = true) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func allowsHitTesting(_ enabled: Bool) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func id<ID: Hashable>(_ id: ID) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func offset(x: CGFloat = 0, y: CGFloat = 0) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func environment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, _ value: V) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func environmentObject<T: AnyObject>(_ object: T) -> _ModifiedView<Self> {
        EnvironmentObjectStore.shared.set(object)
        return _ModifiedView(node: _resolve(self))
    }

    func onSubmit(_ action: @escaping () -> Void) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).onSubmit(action))
    }

    func onSubmit(of triggers: SubmitTriggers = .text, _ action: @escaping () -> Void) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).onSubmit(of: triggers, action))
    }

    func swipeActions(edge: HorizontalEdge = .trailing, allowsFullSwipe: Bool = true, @ViewBuilder content: () -> some View) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func refreshable(action: @escaping @MainActor @Sendable () async -> Void) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func preferredColorScheme(_ scheme: Any?) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func stroke(_ color: Color, lineWidth: CGFloat = 1) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).stroke(color, lineWidth: lineWidth))
    }

    func stroke(_ color: Color, style: StrokeStyle) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).stroke(color, style: style))
    }

    func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).keyboardShortcut(key, modifiers: modifiers))
    }

    func navigationDestination<D: Hashable>(for type: D.Type, @ViewBuilder destination: @escaping (D) -> some View) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).navigationDestination(for: type, destination: destination))
    }

    func onReceive<P: Publisher>(_ publisher: P, perform action: @escaping (P.Output) -> Void) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func simultaneousGesture<G>(_ gesture: G) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).simultaneousGesture(gesture))
    }

    func gesture<G>(_ gesture: G) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).gesture(gesture))
    }

    func highPriorityGesture<G>(_ gesture: G) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).highPriorityGesture(gesture))
    }

    func aspectRatio(_ ratio: CGFloat? = nil, contentMode: ContentMode = .fit) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).aspectRatio(ratio, contentMode: contentMode))
    }

    func lineSpacing(_ spacing: CGFloat) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).lineSpacing(spacing))
    }

    func truncationMode(_ mode: Text.TruncationMode) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).truncationMode(mode))
    }

    func imageScale(_ scale: Image.Scale) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).imageScale(scale))
    }

    func monospacedDigit() -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).monospacedDigit())
    }

    func layoutPriority(_ value: Double) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).layoutPriority(value))
    }

    func scrollPosition(id: Binding<Int?>) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).scrollPosition(id: id))
    }

    func scrollPosition<ID: Hashable>(id: Binding<ID?>, anchor: UnitPoint? = nil) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).scrollPosition(id: id, anchor: anchor))
    }

    func onKeyPress(_ key: KeyEquivalent, action: @escaping () -> KeyPress.Result) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).onKeyPress(key, action: action))
    }

    func symbolEffect(_ effect: SymbolEffect) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).symbolEffect(effect))
    }

    func symbolEffect<V: Equatable>(_ effect: SymbolEffect, value: V) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).symbolEffect(effect, value: value))
    }

    func gridCellUnsizedAxes(_ axes: Axis) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).gridCellUnsizedAxes(axes))
    }

    func strikethrough(_ active: Bool = true, color: Color? = nil) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).strikethrough(active, color: color))
    }

    func rotation3DEffect(_ angle: Angle, axis: (x: CGFloat, y: CGFloat, z: CGFloat)) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).rotation3DEffect(angle, axis: axis))
    }

    func rotation3DEffect(_ angle: Angle, axis: (x: CGFloat, y: CGFloat, z: CGFloat), anchor: UnitPoint = .center, anchorZ: CGFloat = 0, perspective: CGFloat = 1) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).rotation3DEffect(angle, axis: axis, anchor: anchor, anchorZ: anchorZ, perspective: perspective))
    }

    func equatable() -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).equatable())
    }

    func labelStyle<S: LabelStyle>(_ style: S) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).labelStyle(style))
    }

    func listRowBackground<V: View>(_ view: V?) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).listRowBackground(view))
    }

    func toolbar<C: ToolbarContent>(@ToolbarContentBuilder _ content: () -> C) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func toolbar(removing: ToolbarDefaultItemKind?) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).toolbar(removing: removing))
    }

    func presentationDetents(_ detents: Set<PresentationDetent>) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).presentationDetents(detents))
    }

    func interactiveDismissDisabled(_ isDisabled: Bool = true) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).interactiveDismissDisabled(isDisabled))
    }

    func matchedGeometryEffect(id: some Hashable, in namespace: Namespace.ID) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).matchedGeometryEffect(id: id, in: namespace))
    }

    func navigationBarBackButtonHidden(_ hidden: Bool = true) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).navigationBarBackButtonHidden(hidden))
    }

    func textSelection(_ selectability: TextSelectability) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).textSelection(selectability))
    }

    func onMove(perform: ((IndexSet, Int) -> Void)?) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).onMove(perform: perform))
    }

    func onDelete(perform: ((IndexSet) -> Void)?) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).onDelete(perform: perform))
    }

    func progressViewStyle<S: ProgressViewStyle>(_ style: S) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).progressViewStyle(style))
    }

    func scaleEffect(_ scale: CGFloat) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).scaleEffect(scale))
    }

    func scaleEffect(x: CGFloat = 1, y: CGFloat = 1) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).scaleEffect(x: x, y: y))
    }

    func scaleEffect(x: CGFloat = 1, y: CGFloat = 1, anchor: UnitPoint = .center) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).scaleEffect(x: x, y: y))
    }

    func scaleEffect(_ scale: CGFloat, anchor: UnitPoint) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).scaleEffect(scale))
    }

    func fullScreenCover(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: () -> some View) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).fullScreenCover(isPresented: isPresented, onDismiss: onDismiss, content: content))
    }

    func navigationBarTitleDisplayMode(_ displayMode: NavigationBarItem.TitleDisplayMode) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).navigationBarTitleDisplayMode(displayMode))
    }

    func listRowSeparator(_ visibility: Visibility) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).listRowSeparator(visibility))
    }

    func listRowInsets(_ insets: EdgeInsets?) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).listRowInsets(insets))
    }

    func contentMargins(_ edges: Edge.Set = .all, _ length: CGFloat, for placement: ContentMarginPlacement = .automatic) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).contentMargins(edges, length, for: placement))
    }

    func scrollContentBackground(_ visibility: Visibility) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).scrollContentBackground(visibility))
    }

    func scrollIndicators(_ visibility: ScrollIndicatorVisibility) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).scrollIndicators(visibility))
    }

    func popover(isPresented: Binding<Bool>, arrowEdge: Edge = .top, @ViewBuilder content: () -> some View) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).popover(isPresented: isPresented, content: content))
    }

    func focused<V: Hashable>(_ binding: Binding<V?>, equals value: V) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).focused(binding, equals: value))
    }

    func focused(_ condition: Binding<Bool>) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).focused(condition))
    }

    func sensoryFeedback<V: Equatable>(_ feedback: SensoryFeedback, trigger: V) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).sensoryFeedback(feedback, trigger: trigger))
    }

    func headerProminence(_ prominence: Prominence) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).headerProminence(prominence))
    }

    func onChange<V: Equatable>(of value: V, _ action: @escaping (V, V) -> Void) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).onChange(of: value, action))
    }

    func navigationDestination(isPresented: Binding<Bool>, @ViewBuilder destination: () -> some View) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).navigationDestination(isPresented: isPresented, destination: destination))
    }

    func navigationDestination<Item: Hashable>(item: Binding<Item?>, @ViewBuilder destination: @escaping (Item) -> some View) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).navigationDestination(item: item, destination: destination))
    }

    func disableAutocorrection(_ disable: Bool?) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).disableAutocorrection(disable))
    }

    func autocorrectionDisabled(_ disable: Bool = true) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).autocorrectionDisabled(disable))
    }

    func textCase(_ textCase: Text.Case?) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).textCase(textCase))
    }

    func trim(from: CGFloat = 0, to: CGFloat = 1) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).trim(from: from, to: to))
    }

    func mask<V: View>(@ViewBuilder _ mask: () -> V) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).mask(mask))
    }

    func mask<V: View>(_ mask: V) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).mask(mask))
    }

    func controlSize(_ size: ControlSize) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).controlSize(size))
    }

    func formStyle<S: FormStyle>(_ style: S) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).formStyle(style))
    }

    func zIndex(_ value: Double) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).zIndex(value))
    }

    func submitLabel(_ label: SubmitLabel) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).submitLabel(label))
    }

    func colorScheme(_ scheme: ColorScheme) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).colorScheme(scheme))
    }

    func accentColor(_ color: Color?) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).accentColor(color))
    }

    func navigationSplitViewColumnWidth(_ width: CGFloat) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).navigationSplitViewColumnWidth(width))
    }

    func navigationSplitViewColumnWidth(min: CGFloat? = nil, ideal: CGFloat, max: CGFloat? = nil) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).navigationSplitViewColumnWidth(min: min, ideal: ideal, max: max))
    }

    func onDrop(of types: [UTType], isTargeted: Binding<Bool>?, perform: @escaping ([NSItemProvider]) -> Bool) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).onDrop(of: types, isTargeted: isTargeted, perform: perform))
    }

    func clipShape<S: Shape>(_ shape: S) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).clipShape(shape))
    }

    func textContentType(_ type: NSTextContentType?) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).textContentType(type))
    }

    func textInputAutocapitalization(_ autocapitalization: Any?) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func modelContainer(for modelType: Any.Type, inMemory: Bool = false, isAutosaveEnabled: Bool = true, isUndoEnabled: Bool = false) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func modelContainer(for modelTypes: [Any.Type], inMemory: Bool = false, isAutosaveEnabled: Bool = true, isUndoEnabled: Bool = false) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func contextMenu(@ViewBuilder content: () -> some View) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).contextMenu(content: content))
    }


    func accessibilityValue(_ value: String) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).accessibilityValue(value))
    }

    func accessibilityValue<V>(_ value: V) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).accessibilityValue(value))
    }

    func accessibilityAddTraits(_ traits: AccessibilityTraits) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).accessibilityAddTraits(traits))
    }

    func accessibilityRemoveTraits(_ traits: AccessibilityTraits) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).accessibilityRemoveTraits(traits))
    }

    func accessibilityIdentifier(_ identifier: String) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).accessibilityIdentifier(identifier))
    }

    func navigationSplitViewStyle<S: NavigationSplitViewStyleProtocol>(_ style: S) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).navigationSplitViewStyle(style))
    }

    func symbolRenderingMode(_ mode: SymbolRenderingMode?) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).symbolRenderingMode(mode))
    }

    func accessibilityHint(_ hint: String) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).accessibilityHint(hint))
    }

    func blur(radius: CGFloat, opaque: Bool = false) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).blur(radius: radius, opaque: opaque))
    }

    func fixedSize() -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).fixedSize())
    }

    func fixedSize(horizontal: Bool = true, vertical: Bool = true) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).fixedSize(horizontal: horizontal, vertical: vertical))
    }

    func containerRelativeFrame(_ axes: Axis) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).containerRelativeFrame(axes))
    }

    func containerRelativeFrame(_ axes: Axis, alignment: Alignment) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).containerRelativeFrame(axes, alignment: alignment))
    }

    func draggable<T>(_ payload: @autoclosure () -> T) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func dropDestination<T>(for type: T.Type, action: @escaping ([T], CGPoint) -> Bool) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func handlesExternalEvents(preferring: Set<String>, allowing: Set<String>) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func rotationEffect(_ angle: Angle) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).rotationEffect(angle))
    }

    func glassEffect<S: View>(_ style: GlassEffectStyle = .regular, in shape: S) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).glassEffect(style, in: shape))
    }

    func glassEffect(_ style: GlassEffectStyle = .regular) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).glassEffect(style))
    }

    func resizable() -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).resizable())
    }

    func scaledToFit() -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).scaledToFit())
    }

    func scaledToFill() -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self).scaledToFill())
    }

    func contextMenu<S>(forSelectionType: S.Type, @ViewBuilder menu: @escaping (Swift.Set<S>) -> some View) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func contextMenu<S>(forSelectionType: S.Type, @ViewBuilder menu: @escaping (Swift.Set<S>) -> some View, primaryAction: ((Swift.Set<S>) -> Void)? = nil) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func onOpenURL(perform action: @escaping (URL) -> Void) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func menuStyle<S: MenuStyle>(_ style: S) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func toolbarBackground<S: ShapeStyle>(_ style: S, for bars: ToolbarPlacement...) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func toolbarColorScheme(_ colorScheme: ColorScheme?, for bars: ToolbarPlacement...) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func navigationViewStyle<S>(_ style: S) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func focusEffectDisabled(_ disabled: Bool = true) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func symbolEffect(_ effect: SymbolEffect, isActive: Bool) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func onKeyPress(_ key: KeyEquivalent, action: @escaping (KeyPress) -> KeyPress.Result) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }

    func onKeyPress(action: @escaping (KeyPress) -> KeyPress.Result) -> _ModifiedView<Self> {
        _ModifiedView(node: _resolve(self))
    }
}
