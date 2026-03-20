// Re-export Foundation so `import SwiftUI` brings in Foundation types (URL, Date, CGFloat, etc.)
// This matches Apple's SwiftUI behavior.
@_exported import Foundation
@_exported import AppKit

/// The core protocol for SwiftUI views.
public protocol View {
    associatedtype Body: View
    var body: Body { get }
}

/// ViewNode is the terminal View — its body is itself.
extension ViewNode: View {
    public typealias Body = ViewNode
    public var body: ViewNode { self }
}

/// [ViewNode] as a View — allows @ViewBuilder closures to work with `some View`.
extension Array: View where Element == ViewNode {
    public typealias Body = ViewNode
    public var body: ViewNode {
        if count == 1 { return self[0] }
        return .vstack(alignment: .leading, spacing: 0, children: self)
    }
}

/// Color as a View — renders as a filled rect.
extension Color: View {
    public typealias Body = ViewNode
    public var body: ViewNode {
        .rect(width: nil, height: nil, fill: self)
    }
}

// MARK: - View → ViewNode materialization

/// Resolves any View to its terminal ViewNode by walking the body chain.
/// This is intentionally internal to the SwiftUI module.
func _resolve<V: View>(_ view: V) -> ViewNode {
    if let node = view as? ViewNode { return node }
    return _resolve(view.body)
}

// MARK: - Modifier extensions on View

/// These allow chaining modifiers on `some View` without exposing ViewNode
/// to app code. Each modifier materializes the view into a ViewNode internally.
public extension View {

    func frame(width: CGFloat? = nil, height: CGFloat? = nil) -> ViewNode {
        _resolve(self).frame(width: width, height: height)
    }

    func frame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment) -> ViewNode {
        _resolve(self).frame(width: width, height: height)
    }

    func frame(maxWidth: CGFloat? = nil, maxHeight: CGFloat? = nil) -> ViewNode {
        _resolve(self).frame(maxWidth: maxWidth, maxHeight: maxHeight)
    }

    func frame(maxWidth: CGFloat? = nil, maxHeight: CGFloat? = nil, alignment: Alignment) -> ViewNode {
        _resolve(self).frame(maxWidth: maxWidth, maxHeight: maxHeight)
    }

    func frame(minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil, minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil, maxHeight: CGFloat? = nil, alignment: Alignment = .center) -> ViewNode {
        _resolve(self).frame(minWidth: minWidth, idealWidth: idealWidth, maxWidth: maxWidth, minHeight: minHeight, idealHeight: idealHeight, maxHeight: maxHeight, alignment: alignment)
    }

    func padding(_ value: CGFloat) -> ViewNode {
        _resolve(self).padding(value)
    }

    func padding(_ edges: Edge.Set) -> ViewNode {
        _resolve(self).padding(edges)
    }

    func padding(_ edges: Edge.Set, _ value: CGFloat) -> ViewNode {
        _resolve(self).padding(edges, value)
    }

    func padding() -> ViewNode {
        _resolve(self).padding()
    }

    func padding(_ insets: EdgeInsets) -> ViewNode {
        _resolve(self).padding(insets)
    }

    func opacity(_ value: CGFloat) -> ViewNode {
        _resolve(self).opacity(value)
    }

    func foregroundColor(_ color: Color) -> ViewNode {
        _resolve(self).foregroundColor(color)
    }

    func font(_ font: Font) -> ViewNode {
        _resolve(self).font(font)
    }

    func bold() -> ViewNode {
        _resolve(self).bold()
    }

    func italic() -> ViewNode {
        _resolve(self).italic()
    }

    func fontWeight(_ weight: Font.Weight) -> ViewNode {
        _resolve(self).fontWeight(weight)
    }

    func fill(_ color: Color) -> ViewNode {
        _resolve(self).fill(color)
    }

    func fill<S: View>(_ style: S) -> ViewNode {
        _resolve(self).fill(style)
    }

    func cornerRadius(_ radius: CGFloat) -> ViewNode {
        _resolve(self).cornerRadius(radius)
    }

    func shadow(
        color: Color = Color(r: 0, g: 0, b: 0, a: 0.3),
        radius: CGFloat = 10,
        x: CGFloat = 0,
        y: CGFloat = 2
    ) -> ViewNode {
        _resolve(self).shadow(color: color, radius: radius, x: x, y: y)
    }

    func onTapGesture(_ handler: @escaping () -> Void) -> ViewNode {
        _resolve(self).onTapGesture(handler)
    }

    func onTapGesture(count: Int = 1, perform handler: @escaping () -> Void) -> ViewNode {
        _resolve(self).onTapGesture(count: count, perform: handler)
    }

    func onHover(_ handler: @escaping (Bool) -> Void) -> ViewNode {
        _resolve(self).onHover(handler)
    }

    func onContinuousHover(_ handler: @escaping (HoverPhase) -> Void) -> ViewNode {
        _resolve(self).onContinuousHover(handler)
    }

    func clipped(radius: CGFloat = 0) -> ViewNode {
        _resolve(self).clipped(radius: radius)
    }

    func navigationTitle(_ title: String) -> ViewNode {
        _resolve(self).navigationTitle(title)
    }

    func background(_ color: Color) -> ViewNode {
        _resolve(self).background(color)
    }

    func contentShape<S: View>(_ shape: S) -> ViewNode {
        _resolve(self)
    }

    func overlay(@ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        _resolve(self).overlay(content: content)
    }

    func overlay(alignment: HAlignment = .center, @ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        _resolve(self).overlay(alignment: alignment, content: content)
    }

    func overlay<V: View>(_ overlay: V) -> ViewNode {
        _resolve(self).overlay(overlay)
    }

    func disabled(_ isDisabled: Bool) -> ViewNode {
        _resolve(self).disabled(isDisabled)
    }

    func tint(_ color: Color?) -> ViewNode {
        _resolve(self).tint(color)
    }

    func onAppear(perform action: (() -> Void)? = nil) -> ViewNode {
        _resolve(self).onAppear(perform: action)
    }

    func onDisappear(perform action: (() -> Void)? = nil) -> ViewNode {
        _resolve(self).onDisappear(perform: action)
    }

    func task(priority: TaskPriority = .userInitiated, _ action: @escaping @Sendable () async -> Void) -> ViewNode {
        _resolve(self).task(priority: priority, action)
    }

    func task<T: Equatable>(id: T, priority: TaskPriority = .userInitiated, _ action: @escaping @Sendable () async -> Void) -> ViewNode {
        _resolve(self).task(id: id, priority: priority, action)
    }

    func sheet(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        _resolve(self).sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
    }

    func sheet<Item>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> [ViewNode]) -> ViewNode {
        _resolve(self).sheet(item: item, onDismiss: onDismiss, content: content)
    }

    func alert(_ title: String, isPresented: Binding<Bool>, @ViewBuilder actions: () -> [ViewNode]) -> ViewNode {
        _resolve(self).alert(title, isPresented: isPresented, actions: actions)
    }

    func alert(_ title: String, isPresented: Binding<Bool>, @ViewBuilder actions: () -> [ViewNode], @ViewBuilder message: () -> [ViewNode]) -> ViewNode {
        _resolve(self).alert(title, isPresented: isPresented, actions: actions, message: message)
    }

    func confirmationDialog(_ title: String, isPresented: Binding<Bool>, titleVisibility: Any? = nil, @ViewBuilder actions: () -> [ViewNode]) -> ViewNode {
        _resolve(self).confirmationDialog(title, isPresented: isPresented, titleVisibility: titleVisibility, actions: actions)
    }

    func confirmationDialog(_ title: String, isPresented: Binding<Bool>, titleVisibility: Any? = nil, @ViewBuilder actions: () -> [ViewNode], @ViewBuilder message: () -> [ViewNode]) -> ViewNode {
        _resolve(self).confirmationDialog(title, isPresented: isPresented, titleVisibility: titleVisibility, actions: actions, message: message)
    }

    func searchable(text: Binding<String>, placement: Any? = nil, prompt: String? = nil) -> ViewNode {
        _resolve(self).searchable(text: text, placement: placement, prompt: prompt)
    }

    func onChange<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> ViewNode {
        _resolve(self).onChange(of: value, perform: action)
    }

    func onChange<V: Equatable>(of value: V, initial: Bool = false, _ action: @escaping () -> Void) -> ViewNode {
        _resolve(self).onChange(of: value, initial: initial, action)
    }

    func animation(_ animation: Animation?) -> ViewNode {
        _resolve(self).animation(animation)
    }

    func animation<V: Equatable>(_ animation: Animation?, value: V) -> ViewNode {
        _resolve(self).animation(animation, value: value)
    }

    func transition(_ t: AnyTransition) -> ViewNode {
        _resolve(self).transition(t)
    }

    func tabItem(@ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        _resolve(self).tabItem(content: content)
    }

    func tag<V: Hashable>(_ tag: V) -> ViewNode {
        _resolve(self).tag(tag)
    }

    func ignoresSafeArea(_ regions: Any?...) -> ViewNode {
        _resolve(self)
    }

    func safeAreaInset(edge: Edge.Set, @ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        _resolve(self).safeAreaInset(edge: edge, content: content)
    }

    func safeAreaInset(edge: VerticalEdge, alignment: HAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        _resolve(self)
    }

    func safeAreaInset(edge: HorizontalEdge, alignment: VAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        _resolve(self)
    }

    func lineLimit(_ limit: Int?) -> ViewNode {
        _resolve(self).lineLimit(limit)
    }

    func multilineTextAlignment(_ alignment: HAlignment) -> ViewNode {
        _resolve(self).multilineTextAlignment(alignment)
    }

    func textFieldStyle<S>(_ style: S) -> ViewNode {
        _resolve(self).textFieldStyle(style)
    }

    func buttonStyle<S: ButtonStyle>(_ style: S) -> ViewNode {
        _resolve(self).buttonStyle(style)
    }

    func listStyle<S>(_ style: S) -> ViewNode {
        _resolve(self).listStyle(style)
    }

    func pickerStyle<S: PickerStyle>(_ style: S) -> ViewNode {
        _resolve(self).pickerStyle(style)
    }

    func toggleStyle<S>(_ style: S) -> ViewNode {
        _resolve(self).toggleStyle(style)
    }

    func foregroundStyle(_ color: Color) -> ViewNode {
        _resolve(self).foregroundStyle(color)
    }

    func background<S: View>(_ color: Color, in shape: S) -> ViewNode {
        _resolve(self).background(color, in: shape)
    }

    func background<V: View>(_ view: V) -> ViewNode {
        _resolve(self).background(view)
    }

    func background(@ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        _resolve(self).background(content: content)
    }

    func background(alignment: HAlignment = .center, @ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        _resolve(self).background(alignment: alignment, content: content)
    }

    func help(_ text: String) -> ViewNode {
        _resolve(self)
    }

    func accessibilityLabel(_ label: String) -> ViewNode {
        _resolve(self)
    }

    func accessibilityHidden(_ hidden: Bool) -> ViewNode {
        _resolve(self)
    }

    func focusable(_ isFocusable: Bool = true) -> ViewNode {
        _resolve(self)
    }

    func allowsHitTesting(_ enabled: Bool) -> ViewNode {
        _resolve(self)
    }

    func id<ID: Hashable>(_ id: ID) -> ViewNode {
        _resolve(self)
    }

    func offset(x: CGFloat = 0, y: CGFloat = 0) -> ViewNode {
        _resolve(self)
    }

    func environment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, _ value: V) -> ViewNode {
        _resolve(self)
    }

    func environmentObject<T: AnyObject>(_ object: T) -> ViewNode {
        _resolve(self)
    }

    func onSubmit(_ action: @escaping () -> Void) -> ViewNode {
        _resolve(self).onSubmit(action)
    }

    func swipeActions(edge: Any? = nil, allowsFullSwipe: Bool = true, @ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        _resolve(self)
    }

    func refreshable(action: @escaping @Sendable () async -> Void) -> ViewNode {
        _resolve(self)
    }

    func preferredColorScheme(_ scheme: Any?) -> ViewNode {
        _resolve(self)
    }

    func stroke(_ color: Color, lineWidth: CGFloat = 1) -> ViewNode {
        _resolve(self).stroke(color, lineWidth: lineWidth)
    }

    func stroke(_ color: Color, style: StrokeStyle) -> ViewNode {
        _resolve(self).stroke(color, style: style)
    }

    func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command) -> ViewNode {
        _resolve(self).keyboardShortcut(key, modifiers: modifiers)
    }

    func navigationDestination<D: Hashable>(for type: D.Type, @ViewBuilder destination: @escaping (D) -> [ViewNode]) -> ViewNode {
        _resolve(self).navigationDestination(for: type, destination: destination)
    }

    func onReceive<P>(_ publisher: P, perform action: @escaping (P) -> Void) -> ViewNode {
        _resolve(self).onReceive(publisher, perform: action)
    }

    func simultaneousGesture<G>(_ gesture: G) -> ViewNode {
        _resolve(self).simultaneousGesture(gesture)
    }

    func gesture<G>(_ gesture: G) -> ViewNode {
        _resolve(self).gesture(gesture)
    }

    func highPriorityGesture<G>(_ gesture: G) -> ViewNode {
        _resolve(self).highPriorityGesture(gesture)
    }

    func aspectRatio(_ ratio: CGFloat? = nil, contentMode: ContentMode = .fit) -> ViewNode {
        _resolve(self).aspectRatio(ratio, contentMode: contentMode)
    }

    func lineSpacing(_ spacing: CGFloat) -> ViewNode {
        _resolve(self).lineSpacing(spacing)
    }

    func truncationMode(_ mode: Text.TruncationMode) -> ViewNode {
        _resolve(self).truncationMode(mode)
    }

    func imageScale(_ scale: Image.Scale) -> ViewNode {
        _resolve(self).imageScale(scale)
    }

    func monospacedDigit() -> ViewNode {
        _resolve(self).monospacedDigit()
    }

    func layoutPriority(_ value: Double) -> ViewNode {
        _resolve(self).layoutPriority(value)
    }

    func scrollPosition(id: Binding<Int?>) -> ViewNode {
        _resolve(self).scrollPosition(id: id)
    }

    func scrollPosition<ID: Hashable>(id: Binding<ID?>, anchor: UnitPoint? = nil) -> ViewNode {
        _resolve(self).scrollPosition(id: id, anchor: anchor)
    }

    func onKeyPress(_ key: KeyEquivalent, action: @escaping () -> KeyPress.Result) -> ViewNode {
        _resolve(self).onKeyPress(key, action: action)
    }

    func symbolEffect<E>(_ effect: E) -> ViewNode {
        _resolve(self).symbolEffect(effect)
    }

    func gridCellUnsizedAxes(_ axes: Axis) -> ViewNode {
        _resolve(self).gridCellUnsizedAxes(axes)
    }

    func strikethrough(_ active: Bool = true, color: Color? = nil) -> ViewNode {
        _resolve(self).strikethrough(active, color: color)
    }

    func rotation3DEffect(_ angle: Angle, axis: (x: CGFloat, y: CGFloat, z: CGFloat)) -> ViewNode {
        _resolve(self).rotation3DEffect(angle, axis: axis)
    }

    func labelStyle<S: LabelStyle>(_ style: S) -> ViewNode {
        _resolve(self).labelStyle(style)
    }

    func listRowBackground<V: View>(_ view: V?) -> ViewNode {
        _resolve(self).listRowBackground(view)
    }

    func toolbar<C: ToolbarContent>(_ content: () -> C) -> ViewNode {
        _resolve(self).toolbar(content)
    }

    func presentationDetents(_ detents: Set<PresentationDetent>) -> ViewNode {
        _resolve(self).presentationDetents(detents)
    }

    func interactiveDismissDisabled(_ isDisabled: Bool = true) -> ViewNode {
        _resolve(self).interactiveDismissDisabled(isDisabled)
    }

    func matchedGeometryEffect(id: some Hashable, in namespace: Namespace.ID) -> ViewNode {
        _resolve(self).matchedGeometryEffect(id: id, in: namespace)
    }

    func navigationBarBackButtonHidden(_ hidden: Bool = true) -> ViewNode {
        _resolve(self).navigationBarBackButtonHidden(hidden)
    }

    func textSelection(_ selectability: TextSelectability) -> ViewNode {
        _resolve(self).textSelection(selectability)
    }

    func onMove(perform: ((IndexSet, Int) -> Void)?) -> ViewNode {
        _resolve(self).onMove(perform: perform)
    }

    func onDelete(perform: ((IndexSet) -> Void)?) -> ViewNode {
        _resolve(self).onDelete(perform: perform)
    }

    func progressViewStyle<S>(_ style: S) -> ViewNode {
        _resolve(self).progressViewStyle(style)
    }

    func scaleEffect(_ scale: CGFloat) -> ViewNode {
        _resolve(self).scaleEffect(scale)
    }

    func scaleEffect(x: CGFloat = 1, y: CGFloat = 1) -> ViewNode {
        _resolve(self).scaleEffect(x: x, y: y)
    }

    func scaleEffect(x: CGFloat = 1, y: CGFloat = 1, anchor: UnitPoint = .center) -> ViewNode {
        _resolve(self).scaleEffect(x: x, y: y)
    }

    func scaleEffect(_ scale: CGFloat, anchor: UnitPoint) -> ViewNode {
        _resolve(self).scaleEffect(scale)
    }

    func fullScreenCover(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        _resolve(self).fullScreenCover(isPresented: isPresented, onDismiss: onDismiss, content: content)
    }

    func navigationBarTitleDisplayMode(_ displayMode: NavigationBarItem.TitleDisplayMode) -> ViewNode {
        _resolve(self).navigationBarTitleDisplayMode(displayMode)
    }

    func listRowSeparator(_ visibility: Visibility) -> ViewNode {
        _resolve(self).listRowSeparator(visibility)
    }

    func listRowInsets(_ insets: EdgeInsets?) -> ViewNode {
        _resolve(self).listRowInsets(insets)
    }

    func contentMargins(_ edges: Edge.Set = .all, _ length: CGFloat, for placement: ContentMarginPlacement = .automatic) -> ViewNode {
        _resolve(self).contentMargins(edges, length, for: placement)
    }

    func scrollContentBackground(_ visibility: Visibility) -> ViewNode {
        _resolve(self).scrollContentBackground(visibility)
    }

    func scrollIndicators(_ visibility: ScrollIndicatorVisibility) -> ViewNode {
        _resolve(self).scrollIndicators(visibility)
    }

    func popover(isPresented: Binding<Bool>, @ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        _resolve(self).popover(isPresented: isPresented, content: content)
    }

    func focused<V: Hashable>(_ binding: Binding<V?>, equals value: V) -> ViewNode {
        _resolve(self).focused(binding, equals: value)
    }

    func focused(_ condition: Binding<Bool>) -> ViewNode {
        _resolve(self).focused(condition)
    }

    func sensoryFeedback<V: Equatable>(_ feedback: SensoryFeedback, trigger: V) -> ViewNode {
        _resolve(self).sensoryFeedback(feedback, trigger: trigger)
    }

    func headerProminence(_ prominence: Prominence) -> ViewNode {
        _resolve(self).headerProminence(prominence)
    }

    func onChange<V: Equatable>(of value: V, _ action: @escaping (V, V) -> Void) -> ViewNode {
        _resolve(self).onChange(of: value, action)
    }

    func navigationDestination(isPresented: Binding<Bool>, @ViewBuilder destination: () -> [ViewNode]) -> ViewNode {
        _resolve(self).navigationDestination(isPresented: isPresented, destination: destination)
    }

    func navigationDestination<Item: Hashable>(item: Binding<Item?>, @ViewBuilder destination: @escaping (Item) -> [ViewNode]) -> ViewNode {
        _resolve(self).navigationDestination(item: item, destination: destination)
    }

    func disableAutocorrection(_ disable: Bool?) -> ViewNode {
        _resolve(self).disableAutocorrection(disable)
    }

    func autocorrectionDisabled(_ disable: Bool = true) -> ViewNode {
        _resolve(self).autocorrectionDisabled(disable)
    }

    func textCase(_ textCase: Text.Case?) -> ViewNode {
        _resolve(self).textCase(textCase)
    }

    func trim(from: CGFloat = 0, to: CGFloat = 1) -> ViewNode {
        _resolve(self).trim(from: from, to: to)
    }

    func mask<V: View>(@ViewBuilder _ mask: () -> V) -> ViewNode {
        _resolve(self).mask(mask)
    }

    func controlSize(_ size: ControlSize) -> ViewNode {
        _resolve(self).controlSize(size)
    }

    func formStyle<S>(_ style: S) -> ViewNode {
        _resolve(self).formStyle(style)
    }

    func zIndex(_ value: Double) -> ViewNode {
        _resolve(self).zIndex(value)
    }

    func submitLabel(_ label: Any) -> ViewNode {
        _resolve(self).submitLabel(label)
    }

    func colorScheme(_ scheme: ColorScheme) -> ViewNode {
        _resolve(self).colorScheme(scheme)
    }

    func accentColor(_ color: Color?) -> ViewNode {
        _resolve(self).accentColor(color)
    }

    func navigationSplitViewColumnWidth(_ width: CGFloat) -> ViewNode {
        _resolve(self).navigationSplitViewColumnWidth(width)
    }

    func navigationSplitViewColumnWidth(min: CGFloat? = nil, ideal: CGFloat, max: CGFloat? = nil) -> ViewNode {
        _resolve(self).navigationSplitViewColumnWidth(min: min, ideal: ideal, max: max)
    }

    func onDrop(of types: [String], isTargeted: Binding<Bool>?, perform: @escaping ([NSItemProvider]) -> Bool) -> ViewNode {
        _resolve(self).onDrop(of: types, isTargeted: isTargeted, perform: perform)
    }

    func clipShape<S: Shape>(_ shape: S) -> ViewNode {
        _resolve(self).clipShape(shape)
    }

    func textContentType<T>(_ type: T?) -> ViewNode {
        _resolve(self).textContentType(type)
    }

    func textInputAutocapitalization(_ autocapitalization: Any?) -> ViewNode {
        _resolve(self)
    }

    func modelContainer(for modelType: Any.Type, inMemory: Bool = false, isAutosaveEnabled: Bool = true, isUndoEnabled: Bool = false) -> ViewNode {
        _resolve(self)
    }

    func modelContainer(for modelTypes: [Any.Type], inMemory: Bool = false, isAutosaveEnabled: Bool = true, isUndoEnabled: Bool = false) -> ViewNode {
        _resolve(self)
    }
}
