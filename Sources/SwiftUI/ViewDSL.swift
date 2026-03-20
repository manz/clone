import Foundation

// MARK: - Modifier chains on ViewNode

public extension ViewNode {

    /// `.frame(width: 200, height: 100)`
    func frame(width: CGFloat? = nil, height: CGFloat? = nil) -> ViewNode {
        .frame(width: width, height: height, child: self)
    }

    /// `.frame(maxWidth: .infinity)` — fills available space
    func frame(maxWidth: CGFloat? = nil, maxHeight: CGFloat? = nil) -> ViewNode {
        .frame(width: maxWidth, height: maxHeight, child: self)
    }

    /// `.padding(16)` — uniform padding
    func padding(_ value: CGFloat) -> ViewNode {
        .padding(EdgeInsets(all: value), child: self)
    }

    /// `.padding(.horizontal, 16)`
    func padding(_ edges: Edge.Set, _ value: CGFloat) -> ViewNode {
        var insets = EdgeInsets()
        if edges.contains(.top) { insets = EdgeInsets(top: value, leading: insets.leading, bottom: insets.bottom, trailing: insets.trailing) }
        if edges.contains(.bottom) { insets = EdgeInsets(top: insets.top, leading: insets.leading, bottom: value, trailing: insets.trailing) }
        if edges.contains(.leading) { insets = EdgeInsets(top: insets.top, leading: value, bottom: insets.bottom, trailing: insets.trailing) }
        if edges.contains(.trailing) { insets = EdgeInsets(top: insets.top, leading: insets.leading, bottom: insets.bottom, trailing: value) }
        return .padding(insets, child: self)
    }

    /// `.padding()` — default 8pt all around
    func padding() -> ViewNode {
        .padding(EdgeInsets(all: 8), child: self)
    }

    /// `.padding(EdgeInsets(...))` — custom insets
    func padding(_ insets: EdgeInsets) -> ViewNode {
        .padding(insets, child: self)
    }

    /// `.opacity(0.5)`
    func opacity(_ value: CGFloat) -> ViewNode {
        .opacity(value, child: self)
    }

    /// `.foregroundColor(.white)` — applies to text and image nodes
    func foregroundColor(_ color: Color) -> ViewNode {
        switch self {
        case .text(let content, let fontSize, _, let weight):
            return .text(content, fontSize: fontSize, color: color, weight: weight)
        case .image(let name, let width, let height, _):
            return .image(name: name, width: width, height: height, tint: color)
        default:
            return self
        }
    }

    /// `.font(.headline)` / `.font(.system(size: 14, weight: .semibold))`
    func font(_ font: Font) -> ViewNode {
        switch self {
        case .text(let content, _, let color, _):
            return .text(content, fontSize: font.size, color: color, weight: font.internalWeight)
        default:
            return self
        }
    }

    /// `.bold()` — sets font weight to bold.
    func bold() -> ViewNode {
        switch self {
        case .text(let content, let fontSize, let color, _):
            return .text(content, fontSize: fontSize, color: color, weight: .bold)
        default:
            return self
        }
    }

    /// `.italic()` — no-op for now (no italic support in renderer yet).
    func italic() -> ViewNode {
        self
    }

    /// `.fontWeight(.semibold)` — sets text weight. Matches Apple's SwiftUI.
    func fontWeight(_ weight: Font.Weight) -> ViewNode {
        switch self {
        case .text(let content, let fontSize, let color, _):
            let fw = Font(size: fontSize, weight: weight).internalWeight
            return .text(content, fontSize: fontSize, color: color, weight: fw)
        default:
            return self
        }
    }

    /// `.fill(.blue)` — sets the fill color on rect/roundedRect
    func fill(_ color: Color) -> ViewNode {
        switch self {
        case .rect(let width, let height, _):
            return .rect(width: width, height: height, fill: color)
        case .roundedRect(let width, let height, let radius, _):
            return .roundedRect(width: width, height: height, radius: radius, fill: color)
        default:
            return self
        }
    }

    /// `.cornerRadius(12)` — wraps a rect in a roundedRect
    func cornerRadius(_ radius: CGFloat) -> ViewNode {
        switch self {
        case .rect(let width, let height, let fill):
            return .roundedRect(width: width, height: height, radius: radius, fill: fill)
        case .roundedRect(let width, let height, _, let fill):
            return .roundedRect(width: width, height: height, radius: radius, fill: fill)
        default:
            return self
        }
    }

    /// `.shadow(color:radius:x:y:)` — like SwiftUI's shadow modifier
    func shadow(
        color: Color = Color(r: 0, g: 0, b: 0, a: 0.3),
        radius: CGFloat = 10,
        x: CGFloat = 0,
        y: CGFloat = 2
    ) -> ViewNode {
        .shadow(radius: radius, blur: radius, color: color, offsetX: x, offsetY: y, child: self)
    }

    /// `.onTapGesture { }` — registers a closure and attaches its ID
    func onTapGesture(_ handler: @escaping () -> Void) -> ViewNode {
        let id = TapRegistry.shared.register(handler)
        return .onTap(id: id, child: self)
    }

    /// `.onTapGesture(count:perform:)` — matches Apple's SwiftUI.
    /// On Clone, count > 1 is treated as single tap (no multi-tap detection yet).
    func onTapGesture(count: Int = 1, perform handler: @escaping () -> Void) -> ViewNode {
        let id = TapRegistry.shared.register(handler)
        return .onTap(id: id, child: self)
    }

    /// `.onTapGesture(id:)` — attaches a pre-existing tap ID
    func onTapGesture(id: UInt64) -> ViewNode {
        .onTap(id: id, child: self)
    }

    /// `.onHover { isHovered in }` — called when pointer enters/exits this view's frame.
    func onHover(_ handler: @escaping (Bool) -> Void) -> ViewNode {
        let id = HoverRegistry.shared.register(handler)
        return .onHover(id: id, child: self)
    }

    /// `.onContinuousHover { phase in }` — called with pointer position on every move inside this view.
    func onContinuousHover(_ handler: @escaping (HoverPhase) -> Void) -> ViewNode {
        let id = HoverRegistry.shared.registerContinuous(handler)
        return .onHover(id: id, child: self)
    }

    /// `.clipped()` — clips content to this view's frame.
    func clipped(radius: CGFloat = 0) -> ViewNode {
        .clipped(radius: radius, child: self)
    }

    /// `.contentShape(_:)` — defines the tappable area. No-op on Clone (all areas are tappable).
    /// Required on real SwiftUI for hit testing on transparent views.
    func contentShape<S: View>(_ shape: S) -> ViewNode {
        self
    }

    /// `.contextMenu { }` — attaches a context menu to this view.
    func contextMenu(@ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        .contextMenu(child: self, menuItems: content())
    }

    /// `.navigationTitle(_:)` — sets the window title via WindowState.
    func navigationTitle(_ title: String) -> ViewNode {
        WindowState.shared.navigationTitle = title
        return self
    }

    /// `.toolbar { }` — no-op for now (toolbar items are managed by window chrome).
    func toolbar(@ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        self
    }

    /// `.resizable()` — no-op on image stubs, returns self.
    func resizable() -> ViewNode {
        self
    }

    /// `.scaledToFit()` — no-op on image stubs.
    func scaledToFit() -> ViewNode {
        self
    }

    /// `.scaledToFill()` — no-op on image stubs.
    func scaledToFill() -> ViewNode {
        self
    }

    /// `.clipShape(_:)` — no-op for now.
    func clipShape<S: View>(_ shape: S) -> ViewNode {
        self
    }

    /// `.overlay { content }` — layers content on top, like a ZStack.
    func overlay(@ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        .zstack(children: [self] + content())
    }

    /// `.overlay(alignment:content:)` — layers content on top.
    func overlay(alignment: HAlignment = .center, @ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        .zstack(children: [self] + content())
    }

    /// `.overlay(_:)` — layers a single view on top.
    func overlay<V: View>(_ overlay: V) -> ViewNode {
        .zstack(children: [self, _resolve(overlay)])
    }

    /// `.disabled(_:)` — marks the view as disabled. Reduces opacity as visual hint.
    func disabled(_ isDisabled: Bool) -> ViewNode {
        isDisabled ? .opacity(0.5, child: self) : self
    }

    /// `.tint(_:)` — applies a tint color. Maps to foregroundColor for interactive elements.
    func tint(_ color: Color?) -> ViewNode {
        guard let color = color else { return self }
        return foregroundColor(color)
    }

    /// `.onAppear { }` — executes a closure when the view appears.
    /// On Clone, fires immediately during tree build (no lifecycle tracking yet).
    func onAppear(perform action: (() -> Void)? = nil) -> ViewNode {
        action?()
        return self
    }

    /// `.onDisappear { }` — no-op on Clone (no lifecycle tracking yet).
    func onDisappear(perform action: (() -> Void)? = nil) -> ViewNode {
        self
    }

    /// `.task { }` — executes an async closure when the view appears.
    /// On Clone, launches the task immediately (no cancellation on disappear).
    func task(priority: TaskPriority = .userInitiated, _ action: @escaping @Sendable () async -> Void) -> ViewNode {
        Task(priority: priority) { await action() }
        return self
    }

    /// `.task(id:_:)` — executes an async closure when id changes.
    func task<T: Equatable>(id: T, priority: TaskPriority = .userInitiated, _ action: @escaping @Sendable () async -> Void) -> ViewNode {
        Task(priority: priority) { await action() }
        return self
    }

    /// `.sheet(isPresented:onDismiss:content:)` — presents a modal sheet.
    /// On Clone, renders content as overlay when presented.
    func sheet(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        if isPresented.wrappedValue {
            let sheetContent = ViewNode.vstack(alignment: .center, spacing: 0, children: content())
            return .zstack(children: [self, sheetContent])
        }
        return self
    }

    /// `.sheet(item:onDismiss:content:)` — presents a sheet for an optional item.
    func sheet<Item>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> [ViewNode]) -> ViewNode {
        if let value = item.wrappedValue {
            let sheetContent = ViewNode.vstack(alignment: .center, spacing: 0, children: content(value))
            return .zstack(children: [self, sheetContent])
        }
        return self
    }

    /// `.alert(_:isPresented:actions:)` — no-op on Clone.
    func alert(_ title: String, isPresented: Binding<Bool>, @ViewBuilder actions: () -> [ViewNode]) -> ViewNode {
        self
    }

    /// `.alert(_:isPresented:actions:message:)` — no-op on Clone.
    func alert(_ title: String, isPresented: Binding<Bool>, @ViewBuilder actions: () -> [ViewNode], @ViewBuilder message: () -> [ViewNode]) -> ViewNode {
        self
    }

    /// `.confirmationDialog(_:isPresented:actions:)` — no-op on Clone.
    func confirmationDialog(_ title: String, isPresented: Binding<Bool>, titleVisibility: Any? = nil, @ViewBuilder actions: () -> [ViewNode]) -> ViewNode {
        self
    }

    /// `.searchable(text:)` — no-op on Clone.
    func searchable(text: Binding<String>, placement: Any? = nil, prompt: String? = nil) -> ViewNode {
        self
    }

    /// `.onChange(of:perform:)` — no-op on Clone (no observation system yet).
    func onChange<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> ViewNode {
        self
    }

    /// `.onChange(of:initial:_:)` — Swift 5.9+ onChange.
    func onChange<V: Equatable>(of value: V, initial: Bool = false, _ action: @escaping () -> Void) -> ViewNode {
        if initial { action() }
        return self
    }

    /// `.animation(_:)` — no-op on Clone (no animation system).
    func animation(_ animation: Animation?) -> ViewNode {
        self
    }

    /// `.animation(_:value:)` — no-op on Clone.
    func animation<V: Equatable>(_ animation: Animation?, value: V) -> ViewNode {
        self
    }

    /// `.transition(_:)` — no-op on Clone.
    func transition(_ t: AnyTransition) -> ViewNode {
        self
    }

    /// `.tabItem { }` — stores a tab label. No-op rendering on Clone.
    func tabItem(@ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        self
    }

    /// `.tag(_:)` — attaches a tag value for selection. No-op on Clone.
    func tag<V: Hashable>(_ tag: V) -> ViewNode {
        self
    }

    /// `.ignoresSafeArea()` — no-op on Clone.
    func ignoresSafeArea(_ regions: Any?...) -> ViewNode {
        self
    }

    /// `.safeAreaInset(edge:content:)` — no-op on Clone.
    func safeAreaInset(edge: Edge.Set, @ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        self
    }

    /// `.lineLimit(_:)` — no-op on Clone.
    func lineLimit(_ limit: Int?) -> ViewNode {
        self
    }

    /// `.multilineTextAlignment(_:)` — no-op on Clone.
    func multilineTextAlignment(_ alignment: HAlignment) -> ViewNode {
        self
    }

    /// `.textFieldStyle(_:)` — no-op on Clone.
    func textFieldStyle<S>(_ style: S) -> ViewNode {
        self
    }

    /// `.buttonStyle(_:)` — no-op on Clone.
    func buttonStyle<S>(_ style: S) -> ViewNode {
        self
    }

    /// `.listStyle(_:)` — no-op on Clone.
    func listStyle<S>(_ style: S) -> ViewNode {
        self
    }

    /// `.pickerStyle(_:)` — no-op on Clone.
    func pickerStyle<S>(_ style: S) -> ViewNode {
        self
    }

    /// `.toggleStyle(_:)` — no-op on Clone.
    func toggleStyle<S>(_ style: S) -> ViewNode {
        self
    }

    /// `.foregroundStyle(_:)` — maps to foregroundColor for single color.
    func foregroundStyle(_ color: Color) -> ViewNode {
        foregroundColor(color)
    }

    /// `.background(_:in:)` — background with shape. Renders as ZStack.
    func background<S: View>(_ color: Color, in shape: S) -> ViewNode {
        background(color)
    }

    /// `.background(content:)` — background with arbitrary view content.
    func background(@ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        .zstack(children: content() + [self])
    }

    /// `.background(alignment:content:)` — background with view content.
    func background(alignment: HAlignment = .center, @ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        .zstack(children: content() + [self])
    }

    /// `.help(_:)` — tooltip text. No-op on Clone.
    func help(_ text: String) -> ViewNode {
        self
    }

    /// `.accessibilityLabel(_:)` — no-op on Clone.
    func accessibilityLabel(_ label: String) -> ViewNode {
        self
    }

    /// `.accessibilityHidden(_:)` — no-op on Clone.
    func accessibilityHidden(_ hidden: Bool) -> ViewNode {
        self
    }

    /// `.focusable(_:)` — no-op on Clone.
    func focusable(_ isFocusable: Bool = true) -> ViewNode {
        self
    }

    /// `.focused(_:)` — no-op on Clone.
    func focused(_ condition: Any?) -> ViewNode {
        self
    }

    /// `.allowsHitTesting(_:)` — no-op on Clone.
    func allowsHitTesting(_ enabled: Bool) -> ViewNode {
        self
    }

    /// `.id(_:)` — no-op on Clone (no identity tracking yet).
    func id<ID: Hashable>(_ id: ID) -> ViewNode {
        self
    }

    /// `.offset(x:y:)` — no-op on Clone (no offset support yet).
    func offset(x: CGFloat = 0, y: CGFloat = 0) -> ViewNode {
        self
    }

    /// `.rotationEffect(_:)` — no-op on Clone.
    func rotationEffect(_ angle: Any) -> ViewNode {
        self
    }

    /// `.scaleEffect(_:)` — no-op on Clone.
    func scaleEffect(_ scale: CGFloat) -> ViewNode {
        self
    }

    /// `.environment(_:_:)` — no-op on Clone (environment is global).
    func environment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, _ value: V) -> ViewNode {
        self
    }

    /// `.environmentObject(_:)` — no-op on Clone.
    func environmentObject<T: AnyObject>(_ object: T) -> ViewNode {
        self
    }

    /// `.onSubmit(_:)` — no-op on Clone.
    func onSubmit(_ action: @escaping () -> Void) -> ViewNode {
        self
    }

    /// `.swipeActions(edge:content:)` — no-op on Clone.
    func swipeActions(edge: Any? = nil, allowsFullSwipe: Bool = true, @ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        self
    }

    /// `.refreshable(action:)` — no-op on Clone.
    func refreshable(action: @escaping @Sendable () async -> Void) -> ViewNode {
        self
    }

    /// `.symbolRenderingMode(_:)` — no-op on Clone.
    func symbolRenderingMode(_ mode: Any?) -> ViewNode {
        self
    }

    /// `.preferredColorScheme(_:)` — no-op on Clone.
    func preferredColorScheme(_ scheme: Any?) -> ViewNode {
        self
    }
}

/// `.background(_:)` — wraps content in a ZStack with a background color behind it.
public extension ViewNode {
    func background(_ color: Color) -> ViewNode {
        .zstack(children: [
            .rect(width: nil, height: nil, fill: color),
            self,
        ])
    }

    /// `.listRowBackground(_:)` — alias for background, matches SwiftUI naming.
    func listRowBackground(_ color: Color) -> ViewNode {
        background(color)
    }
}
