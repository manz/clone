// Re-export Foundation so `import SwiftUI` brings in Foundation types (URL, Date, CGFloat, etc.)
// This matches Apple's SwiftUI behavior.
@_exported import Foundation
@_exported import AppKit
#if canImport(UniformTypeIdentifiers)
@_exported import UniformTypeIdentifiers
#endif

/// The core protocol for SwiftUI views.
@preconcurrency @MainActor
public protocol View {
    associatedtype Body: View
    var body: Body { get }
}

/// ViewNode is the terminal View — its body is itself.
extension ViewNode: View {
    public typealias Body = ViewNode
    nonisolated public var body: ViewNode { self }
}

/// [ViewNode] as a View — allows @ViewBuilder closures to work with `some View`.
extension Array: View where Element == ViewNode {
    public typealias Body = ViewNode
    nonisolated public var body: ViewNode {
        if count == 1 { return self[0] }
        return .vstack(alignment: .leading, spacing: 0, children: self)
    }
}

/// Color as a View — renders as a filled rect.
extension Color: View {
    public typealias Body = ViewNode
    nonisolated public var body: ViewNode {
        .rect(width: nil, height: nil, fill: self)
    }
}

// MARK: - View → ViewNode materialization

/// Resolves any View to its terminal ViewNode by walking the body chain.
func _resolve<V: View>(_ view: V) -> ViewNode {
    if let node = view as? ViewNode { return node }
    return _resolve(view.body)
}

// MARK: - Modifier extensions on View

/// These allow chaining modifiers on `some View` without exposing ViewNode
/// to app code. Each modifier materializes the view into a ViewNode internally.
public extension View {

    func frame(width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        _resolve(self).frame(width: width, height: height)
    }

    func frame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment) -> some View {
        _resolve(self).frame(width: width, height: height)
    }

    func frame(maxWidth: CGFloat? = nil, maxHeight: CGFloat? = nil) -> some View {
        _resolve(self).frame(maxWidth: maxWidth, maxHeight: maxHeight)
    }

    func frame(maxWidth: CGFloat? = nil, maxHeight: CGFloat? = nil, alignment: Alignment) -> some View {
        _resolve(self).frame(maxWidth: maxWidth, maxHeight: maxHeight)
    }

    func frame(minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil, minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil, maxHeight: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        _resolve(self).frame(minWidth: minWidth, idealWidth: idealWidth, maxWidth: maxWidth, minHeight: minHeight, idealHeight: idealHeight, maxHeight: maxHeight, alignment: alignment)
    }

    func padding(_ value: CGFloat) -> some View {
        _resolve(self).padding(value)
    }

    func padding(_ edges: Edge.Set) -> some View {
        _resolve(self).padding(edges)
    }

    func padding(_ edges: Edge.Set, _ value: CGFloat) -> some View {
        _resolve(self).padding(edges, value)
    }

    func padding() -> some View {
        _resolve(self).padding()
    }

    func padding(_ insets: EdgeInsets) -> some View {
        _resolve(self).padding(insets)
    }

    func opacity(_ value: CGFloat) -> some View {
        _resolve(self).opacity(value)
    }

    func foregroundColor(_ color: Color) -> some View {
        _resolve(self).foregroundColor(color)
    }

    func font(_ font: Font) -> some View {
        _resolve(self).font(font)
    }

    func bold() -> some View {
        _resolve(self).bold()
    }

    func italic() -> some View {
        _resolve(self).italic()
    }

    func fontWeight(_ weight: Font.Weight) -> some View {
        _resolve(self).fontWeight(weight)
    }

    func fill(_ color: Color) -> some View {
        _resolve(self).fill(color)
    }

    func fill<S: View>(_ style: S) -> some View {
        _resolve(self).fill(style)
    }

    func cornerRadius(_ radius: CGFloat) -> some View {
        _resolve(self).cornerRadius(radius)
    }

    func shadow(
        color: Color = Color(r: 0, g: 0, b: 0, a: 0.3),
        radius: CGFloat = 10,
        x: CGFloat = 0,
        y: CGFloat = 2
    ) -> some View {
        _resolve(self).shadow(color: color, radius: radius, x: x, y: y)
    }

    func onTapGesture(_ handler: @escaping () -> Void) -> some View {
        _resolve(self).onTapGesture(handler)
    }

    func onTapGesture(count: Int = 1, perform handler: @escaping () -> Void) -> some View {
        _resolve(self).onTapGesture(count: count, perform: handler)
    }

    func onTapGesture(count: Int = 1, coordinateSpace: CoordinateSpace = .local, perform handler: @escaping (CGPoint) -> Void) -> some View {
        _resolve(self).onTapGesture(count: count, coordinateSpace: coordinateSpace, perform: handler)
    }

    func onHover(_ handler: @escaping (Bool) -> Void) -> some View {
        _resolve(self).onHover(handler)
    }

    func onContinuousHover(_ handler: @escaping (HoverPhase) -> Void) -> some View {
        _resolve(self).onContinuousHover(handler)
    }

    func clipped(radius: CGFloat = 0) -> some View {
        _resolve(self).clipped(radius: radius)
    }

    func navigationTitle(_ title: String) -> some View {
        _resolve(self).navigationTitle(title)
    }

    func background(_ color: Color) -> some View {
        _resolve(self).background(color)
    }

    func contentShape<S: View>(_ shape: S) -> some View {
        _resolve(self)
    }

    func overlay(@ViewBuilder content: () -> [ViewNode]) -> some View {
        _resolve(self).overlay(content: content)
    }

    func overlay(alignment: Alignment = .center, @ViewBuilder content: () -> [ViewNode]) -> some View {
        _resolve(self).overlay(alignment: alignment, content: content)
    }

    func overlay<V: View>(_ overlay: V) -> some View {
        _resolve(self).overlay(overlay)
    }

    func disabled(_ isDisabled: Bool) -> some View {
        _resolve(self).disabled(isDisabled)
    }

    func tint(_ color: Color?) -> some View {
        _resolve(self).tint(color)
    }

    func onAppear(perform action: (() -> Void)? = nil) -> some View {
        _resolve(self).onAppear(perform: action)
    }

    func onDisappear(perform action: (() -> Void)? = nil) -> some View {
        _resolve(self).onDisappear(perform: action)
    }

    func task(priority: TaskPriority = .userInitiated, _ action: @escaping @MainActor @Sendable () async -> Void) -> some View {
        _resolve(self).task(priority: priority, action)
    }

    func task<T: Equatable>(id: T, priority: TaskPriority = .userInitiated, _ action: @escaping @MainActor @Sendable () async -> Void) -> some View {
        _resolve(self).task(id: id, priority: priority, action)
    }

    func sheet(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: () -> [ViewNode]) -> some View {
        _resolve(self).sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
    }

    func sheet<Item>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> [ViewNode]) -> some View {
        _resolve(self).sheet(item: item, onDismiss: onDismiss, content: content)
    }

    func alert(_ title: String, isPresented: Binding<Bool>, @ViewBuilder actions: () -> [ViewNode]) -> some View {
        _resolve(self).alert(title, isPresented: isPresented, actions: actions)
    }

    func alert(_ title: String, isPresented: Binding<Bool>, @ViewBuilder actions: () -> [ViewNode], @ViewBuilder message: () -> [ViewNode]) -> some View {
        _resolve(self).alert(title, isPresented: isPresented, actions: actions, message: message)
    }

    func confirmationDialog(_ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> [ViewNode]) -> some View {
        _resolve(self).confirmationDialog(title, isPresented: isPresented, titleVisibility: titleVisibility, actions: actions)
    }

    func confirmationDialog(_ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> [ViewNode], @ViewBuilder message: () -> [ViewNode]) -> some View {
        _resolve(self).confirmationDialog(title, isPresented: isPresented, titleVisibility: titleVisibility, actions: actions, message: message)
    }

    func searchable(text: Binding<String>, isPresented: Binding<Bool>, placement: Any? = nil, prompt: String? = nil) -> some View {
        _resolve(self).searchable(text: text, isPresented: isPresented, placement: placement, prompt: prompt)
    }

    func searchable(text: Binding<String>, isPresented: Binding<Bool> = .constant(false), isSearchFieldFocused: Binding<Bool>, placement: Any? = nil, prompt: String? = nil) -> some View {
        _resolve(self).searchable(text: text, isPresented: isPresented, isSearchFieldFocused: isSearchFieldFocused, placement: placement, prompt: prompt)
    }

    func searchable(text: Binding<String>, placement: Any? = nil, prompt: String? = nil) -> some View {
        _resolve(self).searchable(text: text, placement: placement, prompt: prompt)
    }

    func onChange<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        _resolve(self).onChange(of: value, perform: action)
    }

    func onChange<V: Equatable>(of value: V, initial: Bool = false, _ action: @escaping () -> Void) -> some View {
        _resolve(self).onChange(of: value, initial: initial, action)
    }

    func animation(_ animation: Animation?) -> some View {
        _resolve(self).animation(animation)
    }

    func animation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        _resolve(self).animation(animation, value: value)
    }

    func transition(_ t: AnyTransition) -> some View {
        _resolve(self).transition(t)
    }

    func tabItem(@ViewBuilder content: () -> [ViewNode]) -> some View {
        _resolve(self).tabItem(content: content)
    }

    func tag<V: Hashable>(_ tag: V) -> some View {
        _resolve(self).tag(tag)
    }

    func ignoresSafeArea(_ regions: Any?...) -> some View {
        _resolve(self)
    }

    func safeAreaInset(edge: Edge.Set, @ViewBuilder content: () -> [ViewNode]) -> some View {
        _resolve(self).safeAreaInset(edge: edge, content: content)
    }

    func safeAreaInset(edge: VerticalEdge, alignment: HAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> [ViewNode]) -> some View {
        _resolve(self)
    }

    func safeAreaInset(edge: HorizontalEdge, alignment: VAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> [ViewNode]) -> some View {
        _resolve(self)
    }

    func lineLimit(_ limit: Int?) -> some View {
        _resolve(self).lineLimit(limit)
    }

    func multilineTextAlignment(_ alignment: TextAlignment) -> some View {
        _resolve(self).multilineTextAlignment(alignment)
    }

    func textFieldStyle<S: TextFieldStyle>(_ style: S) -> some View {
        _resolve(self).textFieldStyle(style)
    }

    func buttonStyle<S: ButtonStyle>(_ style: S) -> some View {
        _resolve(self).buttonStyle(style)
    }

    func listStyle<S: ListStyle>(_ style: S) -> some View {
        _resolve(self).listStyle(style)
    }

    func pickerStyle<S: PickerStyle>(_ style: S) -> some View {
        _resolve(self).pickerStyle(style)
    }

    func toggleStyle<S: ToggleStyle>(_ style: S) -> some View {
        _resolve(self).toggleStyle(style)
    }

    func foregroundStyle(_ color: Color) -> some View {
        _resolve(self).foregroundStyle(color)
    }

    func foregroundStyle<S: View>(_ style: S) -> some View {
        _resolve(self).foregroundStyle(style)
    }

    func foregroundStyle(_ primary: Color, _ secondary: Color) -> some View {
        _resolve(self).foregroundStyle(primary, secondary)
    }

    func foregroundStyle(_ primary: Color, _ secondary: Color, _ tertiary: Color) -> some View {
        _resolve(self).foregroundStyle(primary, secondary, tertiary)
    }

    func foregroundStyle<S1: View, S2: View>(_ primary: S1, _ secondary: S2) -> some View {
        _resolve(self).foregroundStyle(primary, secondary)
    }

    func background<S: View>(_ color: Color, in shape: S) -> some View {
        _resolve(self).background(color, in: shape)
    }

    func background<V: View>(_ view: V) -> some View {
        _resolve(self).background(view)
    }

    func background(@ViewBuilder content: () -> [ViewNode]) -> some View {
        _resolve(self).background(content: content)
    }

    func background(alignment: HAlignment = .center, @ViewBuilder content: () -> [ViewNode]) -> some View {
        _resolve(self).background(alignment: alignment, content: content)
    }

    func help(_ text: String) -> some View {
        _resolve(self)
    }

    func accessibilityLabel(_ label: String) -> some View {
        _resolve(self)
    }

    func accessibilityHidden(_ hidden: Bool) -> some View {
        _resolve(self)
    }

    func focusable(_ isFocusable: Bool = true) -> some View {
        _resolve(self)
    }

    func allowsHitTesting(_ enabled: Bool) -> some View {
        _resolve(self)
    }

    func id<ID: Hashable>(_ id: ID) -> some View {
        _resolve(self)
    }

    func offset(x: CGFloat = 0, y: CGFloat = 0) -> some View {
        _resolve(self)
    }

    func environment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, _ value: V) -> some View {
        _resolve(self)
    }

    func environmentObject<T: AnyObject>(_ object: T) -> some View {
        _resolve(self)
    }

    func onSubmit(_ action: @escaping () -> Void) -> some View {
        _resolve(self).onSubmit(action)
    }

    func onSubmit(of triggers: SubmitTriggers = .text, _ action: @escaping () -> Void) -> some View {
        _resolve(self).onSubmit(of: triggers, action)
    }

    func swipeActions(edge: HorizontalEdge = .trailing, allowsFullSwipe: Bool = true, @ViewBuilder content: () -> [ViewNode]) -> some View {
        _resolve(self)
    }

    func refreshable(action: @escaping @MainActor @Sendable () async -> Void) -> some View {
        _resolve(self)
    }

    func preferredColorScheme(_ scheme: Any?) -> some View {
        _resolve(self)
    }

    func stroke(_ color: Color, lineWidth: CGFloat = 1) -> some View {
        _resolve(self).stroke(color, lineWidth: lineWidth)
    }

    func stroke(_ color: Color, style: StrokeStyle) -> some View {
        _resolve(self).stroke(color, style: style)
    }

    func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command) -> some View {
        _resolve(self).keyboardShortcut(key, modifiers: modifiers)
    }

    func navigationDestination<D: Hashable>(for type: D.Type, @ViewBuilder destination: @escaping (D) -> [ViewNode]) -> some View {
        _resolve(self).navigationDestination(for: type, destination: destination)
    }

    func onReceive<P>(_ publisher: P, perform action: @escaping (P) -> Void) -> some View {
        _resolve(self).onReceive(publisher, perform: action)
    }

    func simultaneousGesture<G>(_ gesture: G) -> some View {
        _resolve(self).simultaneousGesture(gesture)
    }

    func gesture<G>(_ gesture: G) -> some View {
        _resolve(self).gesture(gesture)
    }

    func highPriorityGesture<G>(_ gesture: G) -> some View {
        _resolve(self).highPriorityGesture(gesture)
    }

    func aspectRatio(_ ratio: CGFloat? = nil, contentMode: ContentMode = .fit) -> some View {
        _resolve(self).aspectRatio(ratio, contentMode: contentMode)
    }

    func lineSpacing(_ spacing: CGFloat) -> some View {
        _resolve(self).lineSpacing(spacing)
    }

    func truncationMode(_ mode: Text.TruncationMode) -> some View {
        _resolve(self).truncationMode(mode)
    }

    func imageScale(_ scale: Image.Scale) -> some View {
        _resolve(self).imageScale(scale)
    }

    func monospacedDigit() -> some View {
        _resolve(self).monospacedDigit()
    }

    func layoutPriority(_ value: Double) -> some View {
        _resolve(self).layoutPriority(value)
    }

    func scrollPosition(id: Binding<Int?>) -> some View {
        _resolve(self).scrollPosition(id: id)
    }

    func scrollPosition<ID: Hashable>(id: Binding<ID?>, anchor: UnitPoint? = nil) -> some View {
        _resolve(self).scrollPosition(id: id, anchor: anchor)
    }

    func onKeyPress(_ key: KeyEquivalent, action: @escaping () -> KeyPress.Result) -> some View {
        _resolve(self).onKeyPress(key, action: action)
    }

    func symbolEffect(_ effect: SymbolEffect) -> some View {
        _resolve(self).symbolEffect(effect)
    }

    func symbolEffect<V: Equatable>(_ effect: SymbolEffect, value: V) -> some View {
        _resolve(self).symbolEffect(effect, value: value)
    }

    func gridCellUnsizedAxes(_ axes: Axis) -> some View {
        _resolve(self).gridCellUnsizedAxes(axes)
    }

    func strikethrough(_ active: Bool = true, color: Color? = nil) -> some View {
        _resolve(self).strikethrough(active, color: color)
    }

    func rotation3DEffect(_ angle: Angle, axis: (x: CGFloat, y: CGFloat, z: CGFloat)) -> some View {
        _resolve(self).rotation3DEffect(angle, axis: axis)
    }

    func rotation3DEffect(_ angle: Angle, axis: (x: CGFloat, y: CGFloat, z: CGFloat), anchor: UnitPoint = .center, anchorZ: CGFloat = 0, perspective: CGFloat = 1) -> some View {
        _resolve(self).rotation3DEffect(angle, axis: axis, anchor: anchor, anchorZ: anchorZ, perspective: perspective)
    }

    func equatable() -> some View {
        _resolve(self).equatable()
    }

    func labelStyle<S: LabelStyle>(_ style: S) -> some View {
        _resolve(self).labelStyle(style)
    }

    func listRowBackground<V: View>(_ view: V?) -> some View {
        _resolve(self).listRowBackground(view)
    }

    func toolbar<C: ToolbarContent>(_ content: () -> C) -> some View {
        _resolve(self).toolbar(content)
    }

    func toolbar(removing: ToolbarDefaultItemKind?) -> some View {
        _resolve(self).toolbar(removing: removing)
    }

    func presentationDetents(_ detents: Set<PresentationDetent>) -> some View {
        _resolve(self).presentationDetents(detents)
    }

    func interactiveDismissDisabled(_ isDisabled: Bool = true) -> some View {
        _resolve(self).interactiveDismissDisabled(isDisabled)
    }

    func matchedGeometryEffect(id: some Hashable, in namespace: Namespace.ID) -> some View {
        _resolve(self).matchedGeometryEffect(id: id, in: namespace)
    }

    func navigationBarBackButtonHidden(_ hidden: Bool = true) -> some View {
        _resolve(self).navigationBarBackButtonHidden(hidden)
    }

    func textSelection(_ selectability: TextSelectability) -> some View {
        _resolve(self).textSelection(selectability)
    }

    func onMove(perform: ((IndexSet, Int) -> Void)?) -> some View {
        _resolve(self).onMove(perform: perform)
    }

    func onDelete(perform: ((IndexSet) -> Void)?) -> some View {
        _resolve(self).onDelete(perform: perform)
    }

    func progressViewStyle<S: ProgressViewStyle>(_ style: S) -> some View {
        _resolve(self).progressViewStyle(style)
    }

    func scaleEffect(_ scale: CGFloat) -> some View {
        _resolve(self).scaleEffect(scale)
    }

    func scaleEffect(x: CGFloat = 1, y: CGFloat = 1) -> some View {
        _resolve(self).scaleEffect(x: x, y: y)
    }

    func scaleEffect(x: CGFloat = 1, y: CGFloat = 1, anchor: UnitPoint = .center) -> some View {
        _resolve(self).scaleEffect(x: x, y: y)
    }

    func scaleEffect(_ scale: CGFloat, anchor: UnitPoint) -> some View {
        _resolve(self).scaleEffect(scale)
    }

    func fullScreenCover(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: () -> [ViewNode]) -> some View {
        _resolve(self).fullScreenCover(isPresented: isPresented, onDismiss: onDismiss, content: content)
    }

    func navigationBarTitleDisplayMode(_ displayMode: NavigationBarItem.TitleDisplayMode) -> some View {
        _resolve(self).navigationBarTitleDisplayMode(displayMode)
    }

    func listRowSeparator(_ visibility: Visibility) -> some View {
        _resolve(self).listRowSeparator(visibility)
    }

    func listRowInsets(_ insets: EdgeInsets?) -> some View {
        _resolve(self).listRowInsets(insets)
    }

    func contentMargins(_ edges: Edge.Set = .all, _ length: CGFloat, for placement: ContentMarginPlacement = .automatic) -> some View {
        _resolve(self).contentMargins(edges, length, for: placement)
    }

    func scrollContentBackground(_ visibility: Visibility) -> some View {
        _resolve(self).scrollContentBackground(visibility)
    }

    func scrollIndicators(_ visibility: ScrollIndicatorVisibility) -> some View {
        _resolve(self).scrollIndicators(visibility)
    }

    func popover(isPresented: Binding<Bool>, arrowEdge: Edge = .top, @ViewBuilder content: () -> [ViewNode]) -> some View {
        _resolve(self).popover(isPresented: isPresented, content: content)
    }

    func focused<V: Hashable>(_ binding: Binding<V?>, equals value: V) -> some View {
        _resolve(self).focused(binding, equals: value)
    }

    func focused(_ condition: Binding<Bool>) -> some View {
        _resolve(self).focused(condition)
    }

    func sensoryFeedback<V: Equatable>(_ feedback: SensoryFeedback, trigger: V) -> some View {
        _resolve(self).sensoryFeedback(feedback, trigger: trigger)
    }

    func headerProminence(_ prominence: Prominence) -> some View {
        _resolve(self).headerProminence(prominence)
    }

    func onChange<V: Equatable>(of value: V, _ action: @escaping (V, V) -> Void) -> some View {
        _resolve(self).onChange(of: value, action)
    }

    func navigationDestination(isPresented: Binding<Bool>, @ViewBuilder destination: () -> [ViewNode]) -> some View {
        _resolve(self).navigationDestination(isPresented: isPresented, destination: destination)
    }

    func navigationDestination<Item: Hashable>(item: Binding<Item?>, @ViewBuilder destination: @escaping (Item) -> [ViewNode]) -> some View {
        _resolve(self).navigationDestination(item: item, destination: destination)
    }

    func disableAutocorrection(_ disable: Bool?) -> some View {
        _resolve(self).disableAutocorrection(disable)
    }

    func autocorrectionDisabled(_ disable: Bool = true) -> some View {
        _resolve(self).autocorrectionDisabled(disable)
    }

    func textCase(_ textCase: Text.Case?) -> some View {
        _resolve(self).textCase(textCase)
    }

    func trim(from: CGFloat = 0, to: CGFloat = 1) -> some View {
        _resolve(self).trim(from: from, to: to)
    }

    func mask<V: View>(@ViewBuilder _ mask: () -> V) -> some View {
        _resolve(self).mask(mask)
    }

    func mask<V: View>(_ mask: V) -> some View {
        _resolve(self).mask(mask)
    }

    func controlSize(_ size: ControlSize) -> some View {
        _resolve(self).controlSize(size)
    }

    func formStyle<S: FormStyle>(_ style: S) -> some View {
        _resolve(self).formStyle(style)
    }

    func zIndex(_ value: Double) -> some View {
        _resolve(self).zIndex(value)
    }

    func submitLabel(_ label: SubmitLabel) -> some View {
        _resolve(self).submitLabel(label)
    }

    func colorScheme(_ scheme: ColorScheme) -> some View {
        _resolve(self).colorScheme(scheme)
    }

    func accentColor(_ color: Color?) -> some View {
        _resolve(self).accentColor(color)
    }

    func navigationSplitViewColumnWidth(_ width: CGFloat) -> some View {
        _resolve(self).navigationSplitViewColumnWidth(width)
    }

    func navigationSplitViewColumnWidth(min: CGFloat? = nil, ideal: CGFloat, max: CGFloat? = nil) -> some View {
        _resolve(self).navigationSplitViewColumnWidth(min: min, ideal: ideal, max: max)
    }

    func onDrop(of types: [UTType], isTargeted: Binding<Bool>?, perform: @escaping ([NSItemProvider]) -> Bool) -> some View {
        _resolve(self).onDrop(of: types, isTargeted: isTargeted, perform: perform)
    }

    func clipShape<S: Shape>(_ shape: S) -> some View {
        _resolve(self).clipShape(shape)
    }

    func textContentType(_ type: NSTextContentType?) -> some View {
        _resolve(self).textContentType(type)
    }

    func textInputAutocapitalization(_ autocapitalization: Any?) -> some View {
        _resolve(self)
    }

    func modelContainer(for modelType: Any.Type, inMemory: Bool = false, isAutosaveEnabled: Bool = true, isUndoEnabled: Bool = false) -> some View {
        _resolve(self)
    }

    func modelContainer(for modelTypes: [Any.Type], inMemory: Bool = false, isAutosaveEnabled: Bool = true, isUndoEnabled: Bool = false) -> some View {
        _resolve(self)
    }

    func contextMenu(@ViewBuilder content: () -> [ViewNode]) -> some View {
        _resolve(self).contextMenu(content: content)
    }

    func toolbar(@ViewBuilder content: () -> [ViewNode]) -> some View {
        _resolve(self).toolbar(content: content)
    }

    func accessibilityValue(_ value: String) -> some View {
        _resolve(self).accessibilityValue(value)
    }

    func accessibilityValue<V>(_ value: V) -> some View {
        _resolve(self).accessibilityValue(value)
    }

    func accessibilityAddTraits(_ traits: AccessibilityTraits) -> some View {
        _resolve(self).accessibilityAddTraits(traits)
    }

    func accessibilityRemoveTraits(_ traits: AccessibilityTraits) -> some View {
        _resolve(self).accessibilityRemoveTraits(traits)
    }

    func accessibilityIdentifier(_ identifier: String) -> some View {
        _resolve(self).accessibilityIdentifier(identifier)
    }

    func navigationSplitViewStyle<S: NavigationSplitViewStyleProtocol>(_ style: S) -> some View {
        _resolve(self).navigationSplitViewStyle(style)
    }

    func symbolRenderingMode(_ mode: SymbolRenderingMode?) -> some View {
        _resolve(self).symbolRenderingMode(mode)
    }

    func accessibilityHint(_ hint: String) -> some View {
        _resolve(self).accessibilityHint(hint)
    }

    func blur(radius: CGFloat, opaque: Bool = false) -> some View {
        _resolve(self).blur(radius: radius, opaque: opaque)
    }

    func fixedSize() -> some View {
        _resolve(self).fixedSize()
    }

    func fixedSize(horizontal: Bool = true, vertical: Bool = true) -> some View {
        _resolve(self).fixedSize(horizontal: horizontal, vertical: vertical)
    }

    func containerRelativeFrame(_ axes: Axis) -> some View {
        _resolve(self).containerRelativeFrame(axes)
    }

    func containerRelativeFrame(_ axes: Axis, alignment: Alignment) -> some View {
        _resolve(self).containerRelativeFrame(axes, alignment: alignment)
    }

    func draggable<T>(_ payload: @autoclosure () -> T) -> some View {
        _resolve(self)
    }

    func dropDestination<T>(for type: T.Type, action: @escaping ([T], CGPoint) -> Bool) -> some View {
        _resolve(self)
    }

    func handlesExternalEvents(preferring: Set<String>, allowing: Set<String>) -> some View {
        _resolve(self)
    }

    func glassEffect<S: View>(_ style: GlassEffectStyle = .regular, in shape: S) -> some View {
        _resolve(self).glassEffect(style, in: shape)
    }

    func glassEffect(_ style: GlassEffectStyle = .regular) -> some View {
        _resolve(self).glassEffect(style)
    }
}
