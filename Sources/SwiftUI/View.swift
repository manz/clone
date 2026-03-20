import Foundation

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

    func frame(maxWidth: CGFloat? = nil, maxHeight: CGFloat? = nil) -> ViewNode {
        _resolve(self).frame(maxWidth: maxWidth, maxHeight: maxHeight)
    }

    func padding(_ value: CGFloat) -> ViewNode {
        _resolve(self).padding(value)
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

    func lineLimit(_ limit: Int?) -> ViewNode {
        _resolve(self).lineLimit(limit)
    }

    func multilineTextAlignment(_ alignment: HAlignment) -> ViewNode {
        _resolve(self).multilineTextAlignment(alignment)
    }

    func textFieldStyle<S>(_ style: S) -> ViewNode {
        _resolve(self).textFieldStyle(style)
    }

    func buttonStyle<S>(_ style: S) -> ViewNode {
        _resolve(self).buttonStyle(style)
    }

    func listStyle<S>(_ style: S) -> ViewNode {
        _resolve(self).listStyle(style)
    }

    func pickerStyle<S>(_ style: S) -> ViewNode {
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
}
