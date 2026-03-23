import Foundation
import Combine

// MARK: - Modifier chains on ViewNode

public extension ViewNode {

    /// `.frame(width: 200, height: 100)`
    func frame(width: CGFloat? = nil, height: CGFloat? = nil) -> ViewNode {
        .frame(width: width, height: height, child: self)
    }

    /// `.frame(width:height:alignment:)` — with alignment parameter
    func frame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment) -> ViewNode {
        .frame(width: width, height: height, child: self)
    }

    /// `.frame(maxWidth: .infinity)` — fills available space
    func frame(maxWidth: CGFloat? = nil, maxHeight: CGFloat? = nil) -> ViewNode {
        // .infinity means "fill available space" → use nil (fills constraint)
        let w: CGFloat? = maxWidth == .infinity ? nil : maxWidth
        let h: CGFloat? = maxHeight == .infinity ? nil : maxHeight
        return .frame(width: w, height: h, child: self)
    }

    /// `.frame(maxWidth:maxHeight:alignment:)` — fills available space with alignment
    func frame(maxWidth: CGFloat? = nil, maxHeight: CGFloat? = nil, alignment: Alignment) -> ViewNode {
        let w: CGFloat? = maxWidth == .infinity ? nil : maxWidth
        let h: CGFloat? = maxHeight == .infinity ? nil : maxHeight
        return .frame(width: w, height: h, child: self)
    }

    /// `.frame(minWidth:idealWidth:maxWidth:minHeight:idealHeight:maxHeight:alignment:)` — flexible frame
    func frame(minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil, minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil, maxHeight: CGFloat? = nil, alignment: Alignment = .center) -> ViewNode {
        let w = (maxWidth == .infinity ? nil : maxWidth) ?? idealWidth ?? minWidth
        let h = (maxHeight == .infinity ? nil : maxHeight) ?? idealHeight ?? minHeight
        return .frame(width: w, height: h, child: self)
    }

    /// `.padding(16)` — uniform padding
    func padding(_ value: CGFloat) -> ViewNode {
        .padding(EdgeInsets(all: value), child: self)
    }

    /// `.padding(.horizontal)` — edge-specific with default 8pt
    func padding(_ edges: Edge.Set) -> ViewNode {
        padding(edges, 8)
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

    /// `.fill(_:)` — fills with an arbitrary ShapeStyle/View (extracts first color from gradient).
    @MainActor func fill<S: View>(_ style: S) -> ViewNode {
        // Try to extract a representative color from the style's body
        let resolved = _resolve(style)
        switch resolved {
        case .rect(_, _, let fillColor):
            return fill(fillColor)
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

    /// `.onTapGesture(count:coordinateSpace:perform:)` — with location.
    func onTapGesture(count: Int = 1, coordinateSpace: CoordinateSpace = .local, perform handler: @escaping (CGPoint) -> Void) -> ViewNode {
        let id = TapRegistry.shared.register { handler(.zero) }
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
    func contextMenu(@ViewBuilder content: () -> some View) -> ViewNode {
        .contextMenu(child: self, menuItems: _flattenToNodes(content()))
    }

    /// `.contextMenu(forSelectionType:menu:)` — context menu for selected items.
    func contextMenu<S>(forSelectionType: S.Type, @ViewBuilder menu: @escaping (Swift.Set<S>) -> some View) -> ViewNode {
        self
    }

    /// `.contextMenu(forSelectionType:menu:primaryAction:)` — with primary action.
    func contextMenu<S>(forSelectionType: S.Type, @ViewBuilder menu: @escaping (Swift.Set<S>) -> some View, primaryAction: ((Swift.Set<S>) -> Void)? = nil) -> ViewNode {
        self
    }

    /// `.navigationTitle(_:)` — sets the window title via WindowState.
    func navigationTitle(_ title: String) -> ViewNode {
        WindowState.shared.navigationTitle = title
        return self
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
    func overlay(@ViewBuilder content: () -> some View) -> ViewNode {
        .zstack(children: [self] + _flattenToNodes(content()))
    }

    /// `.overlay(alignment:content:)` — layers content on top.
    func overlay(alignment: Alignment = .center, @ViewBuilder content: () -> some View) -> ViewNode {
        .zstack(children: [self] + _flattenToNodes(content()))
    }

    /// `.overlay(_:)` — layers a single view on top.
    @MainActor func overlay<V: View>(_ overlay: V) -> ViewNode {
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
    /// Fires only once using OnceRegistry to prevent re-firing every frame.
    func onAppear(perform action: (() -> Void)? = nil) -> ViewNode {
        if let action = action {
            OnceRegistry.shared.runOnce(action)
        }
        return self
    }

    /// `.onDisappear { }` — no-op on Clone (no lifecycle tracking yet).
    func onDisappear(perform action: (() -> Void)? = nil) -> ViewNode {
        self
    }

    /// `.task { }` — executes an async closure when the view appears.
    /// Fires only once per unique call site.
    func task(priority: TaskPriority = .userInitiated, _ action: @escaping @MainActor @Sendable () async -> Void) -> ViewNode {
        OnceRegistry.shared.runOnce {
            Task(priority: priority) { @MainActor in await action() }
        }
        return self
    }

    /// `.task(id:_:)` — executes an async closure when id changes.
    func task<T: Equatable>(id: T, priority: TaskPriority = .userInitiated, _ action: @escaping @MainActor @Sendable () async -> Void) -> ViewNode {
        OnceRegistry.shared.runOnce {
            Task(priority: priority) { @MainActor in await action() }
        }
        return self
    }

    /// `.sheet(isPresented:onDismiss:content:)` — presents a modal sheet.
    /// On Clone, renders content as overlay when presented.
    func sheet(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: () -> some View) -> ViewNode {
        if isPresented.wrappedValue {
            let sheetContent = ViewNode.vstack(alignment: .center, spacing: 0, children: _flattenToNodes(content()))
            return .zstack(children: [self, sheetContent])
        }
        return self
    }

    /// `.sheet(item:onDismiss:content:)` — presents a sheet for an optional item.
    func sheet<Item>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> some View) -> ViewNode {
        if let value = item.wrappedValue {
            let sheetContent = ViewNode.vstack(alignment: .center, spacing: 0, children: _flattenToNodes(content(value)))
            return .zstack(children: [self, sheetContent])
        }
        return self
    }

    /// `.alert(_:isPresented:actions:)` — no-op on Clone.
    func alert(_ title: String, isPresented: Binding<Bool>, @ViewBuilder actions: () -> some View) -> ViewNode {
        self
    }

    /// `.alert(_:isPresented:actions:message:)` — no-op on Clone.
    func alert(_ title: String, isPresented: Binding<Bool>, @ViewBuilder actions: () -> some View, @ViewBuilder message: () -> some View) -> ViewNode {
        self
    }

    /// `.confirmationDialog(_:isPresented:actions:)` — no-op on Clone.
    func confirmationDialog(_ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> some View) -> ViewNode {
        self
    }

    /// `.confirmationDialog(_:isPresented:actions:message:)` — no-op on Clone.
    func confirmationDialog(_ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> some View, @ViewBuilder message: () -> some View) -> ViewNode {
        self
    }

    /// `.searchable(text:isPresented:)` — no-op on Clone.
    func searchable(text: Binding<String>, isPresented: Binding<Bool>, placement: Any? = nil, prompt: String? = nil) -> ViewNode {
        self
    }

    /// `.searchable(text:isPresented:isSearchFieldFocused:)` — no-op on Clone.
    func searchable(text: Binding<String>, isPresented: Binding<Bool> = .constant(false), isSearchFieldFocused: Binding<Bool>, placement: Any? = nil, prompt: String? = nil) -> ViewNode {
        self
    }

    /// `.searchable(text:)` — no-op on Clone.
    func searchable(text: Binding<String>, placement: Any? = nil, prompt: String? = nil) -> ViewNode {
        self
    }

    /// `.onChange(of:perform:)` — no-op on Clone (no observation system yet).
    func onChange<V: Equatable>(of value: V, perform action: @escaping (V) -> Void, file: String = #fileID, line: Int = #line) -> ViewNode {
        let key = OnChangeRegistry.shared.track(value: value, file: file, line: line)
        if let (_, changed) = key, changed {
            let v = value
            OnChangeRegistry.shared.enqueue { action(v) }
        }
        return self
    }

    /// `.onChange(of:initial:_:)` — Swift 5.9+ onChange.
    func onChange<V: Equatable>(of value: V, initial: Bool = false, _ action: @escaping () -> Void, file: String = #fileID, line: Int = #line) -> ViewNode {
        let key = OnChangeRegistry.shared.track(value: value, file: file, line: line)
        if let (_, changed) = key, changed {
            OnChangeRegistry.shared.enqueue { action() }
        } else if initial, key == nil {
            OnChangeRegistry.shared.enqueue { action() }
        }
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
    func tabItem(@ViewBuilder content: () -> some View) -> ViewNode {
        self
    }

    /// `.tag(_:)` — attaches a tag value for selection. No-op on ViewNode.
    func tag<V: Hashable>(_ tag: V) -> ViewNode {
        self
    }

    /// `.ignoresSafeArea()` — no-op on Clone.
    func ignoresSafeArea(_ regions: Any?...) -> ViewNode {
        self
    }

    /// `.safeAreaInset(edge:content:)` — no-op on Clone.
    func safeAreaInset(edge: Edge.Set, @ViewBuilder content: () -> some View) -> ViewNode {
        self
    }

    /// `.safeAreaInset(edge:alignment:spacing:content:)` — no-op on Clone.
    func safeAreaInset(edge: VerticalEdge, alignment: HAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> some View) -> ViewNode {
        self
    }

    /// `.safeAreaInset(edge:alignment:spacing:content:)` — horizontal variant, no-op on Clone.
    func safeAreaInset(edge: HorizontalEdge, alignment: VAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> some View) -> ViewNode {
        self
    }

    /// `.lineLimit(_:)` — no-op on Clone.
    func lineLimit(_ limit: Int?) -> ViewNode {
        self
    }

    /// `.multilineTextAlignment(_:)` — no-op on Clone.
    func multilineTextAlignment(_ alignment: TextAlignment) -> ViewNode {
        self
    }

    /// `.textFieldStyle(_:)` — no-op on Clone.
    func textFieldStyle<S: TextFieldStyle>(_ style: S) -> ViewNode {
        self
    }

    /// `.buttonStyle(_:)` — no-op on Clone.
    func buttonStyle<S: ButtonStyle>(_ style: S) -> ViewNode {
        self
    }

    /// `.listStyle(_:)` — no-op on Clone.
    func listStyle<S: ListStyle>(_ style: S) -> ViewNode {
        self
    }

    /// `.pickerStyle(_:)` — no-op on Clone.
    func pickerStyle<S: PickerStyle>(_ style: S) -> ViewNode {
        self
    }

    /// `.toggleStyle(_:)` — no-op on Clone.
    func toggleStyle<S: ToggleStyle>(_ style: S) -> ViewNode {
        self
    }

    /// `.foregroundStyle(_:)` — maps to foregroundColor for single color.
    func foregroundStyle(_ color: Color) -> ViewNode {
        foregroundColor(color)
    }

    /// `.foregroundStyle(_:)` — accepts any ShapeStyle/View (gradient, etc). No-op on Clone.
    func foregroundStyle<S: View>(_ style: S) -> ViewNode {
        self
    }

    /// `.foregroundStyle(_:_:)` — two-level hierarchy. Maps to primary color.
    func foregroundStyle(_ primary: Color, _ secondary: Color) -> ViewNode {
        foregroundColor(primary)
    }

    /// `.foregroundStyle(_:_:_:)` — three-level hierarchy.
    func foregroundStyle(_ primary: Color, _ secondary: Color, _ tertiary: Color) -> ViewNode {
        foregroundColor(primary)
    }

    /// `.foregroundStyle(_:_:)` — generic View variant.
    func foregroundStyle<S1: View, S2: View>(_ primary: S1, _ secondary: S2) -> ViewNode {
        self
    }

    /// `.background(_:in:)` — background with shape. Renders as ZStack.
    func background<S: View>(_ color: Color, in shape: S) -> ViewNode {
        background(color)
    }

    /// `.background(content:)` — background with arbitrary view content.
    func background(@ViewBuilder content: () -> some View) -> ViewNode {
        .zstack(children: _flattenToNodes(content()) + [self])
    }

    /// `.background(alignment:content:)` — background with view content.
    func background(alignment: HAlignment = .center, @ViewBuilder content: () -> some View) -> ViewNode {
        .zstack(children: _flattenToNodes(content()) + [self])
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
    func rotationEffect(_ angle: Angle) -> ViewNode {
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

    /// `.environmentObject(_:)` — stores object in global environment.
    func environmentObject<T: AnyObject>(_ object: T) -> ViewNode {
        EnvironmentObjectStore.shared.set(object)
        return self
    }

    /// `.onSubmit(_:)` — no-op on Clone.
    func onSubmit(_ action: @escaping () -> Void) -> ViewNode {
        self
    }

    /// `.onSubmit(of:_:)` — no-op on Clone.
    func onSubmit(of triggers: SubmitTriggers = .text, _ action: @escaping () -> Void) -> ViewNode {
        self
    }

    /// `.swipeActions(edge:content:)` — no-op on Clone.
    func swipeActions(edge: HorizontalEdge = .trailing, allowsFullSwipe: Bool = true, @ViewBuilder content: () -> some View) -> ViewNode {
        self
    }

    /// `.refreshable(action:)` — no-op on Clone.
    func refreshable(action: @escaping @MainActor @Sendable () async -> Void) -> ViewNode {
        self
    }

    /// `.symbolRenderingMode(_:)` — no-op on Clone.
    func symbolRenderingMode(_ mode: SymbolRenderingMode?) -> ViewNode {
        self
    }

    /// `.preferredColorScheme(_:)` — no-op on Clone.
    func preferredColorScheme(_ scheme: Any?) -> ViewNode {
        self
    }

    /// `.stroke(_:lineWidth:)` — no-op on Clone.
    func stroke(_ color: Color, lineWidth: CGFloat = 1) -> ViewNode { self }

    /// `.stroke(_:style:)` — no-op on Clone.
    func stroke(_ color: Color, style: StrokeStyle) -> ViewNode { self }

    /// `.keyboardShortcut(_:modifiers:)` — no-op on Clone.
    func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command) -> ViewNode { self }

    /// `.navigationDestination(for:destination:)` — no-op on Clone.
    func navigationDestination<D: Hashable>(for type: D.Type, @ViewBuilder destination: @escaping (D) -> some View) -> ViewNode { self }

    /// `.navigationDestination(isPresented:destination:)` — no-op on Clone.
    func navigationDestination(isPresented: Binding<Bool>, @ViewBuilder destination: () -> some View) -> ViewNode { self }

    /// `.navigationDestination(item:destination:)` — no-op on Clone.
    func navigationDestination<Item: Hashable>(item: Binding<Item?>, @ViewBuilder destination: @escaping (Item) -> some View) -> ViewNode { self }

    /// `.onReceive(_:perform:)` — no-op on Clone. Uses Combine Publisher protocol.
    func onReceive<P: Publisher>(_ publisher: P, perform action: @escaping (P.Output) -> Void) -> ViewNode { self }

    /// `.simultaneousGesture(_:)` — no-op on Clone.
    func simultaneousGesture<G>(_ gesture: G) -> ViewNode { self }

    /// `.gesture(_:)` — no-op on Clone.
    func gesture<G>(_ gesture: G) -> ViewNode { self }

    /// `.highPriorityGesture(_:)` — no-op on Clone.
    func highPriorityGesture<G>(_ gesture: G) -> ViewNode { self }

    /// `.aspectRatio(_:contentMode:)` — no-op on Clone.
    func aspectRatio(_ ratio: CGFloat? = nil, contentMode: ContentMode = .fit) -> ViewNode { self }

    /// `.lineSpacing(_:)` — no-op on Clone.
    func lineSpacing(_ spacing: CGFloat) -> ViewNode { self }

    /// `.truncationMode(_:)` — no-op on Clone.
    func truncationMode(_ mode: Text.TruncationMode) -> ViewNode { self }

    /// `.imageScale(_:)` — no-op on Clone.
    func imageScale(_ scale: Image.Scale) -> ViewNode { self }

    /// `.monospacedDigit()` — no-op on Clone.
    func monospacedDigit() -> ViewNode { self }

    /// `.layoutPriority(_:)` — no-op on Clone.
    func layoutPriority(_ value: Double) -> ViewNode { self }

    /// `.scrollPosition(id:)` — no-op on Clone.
    func scrollPosition(id: Binding<Int?>) -> ViewNode { self }

    /// `.scrollPosition(id:anchor:)` — no-op on Clone.
    func scrollPosition<ID: Hashable>(id: Binding<ID?>, anchor: UnitPoint? = nil) -> ViewNode { self }

    /// `.glassEffect(_:)` — no-op on Clone.
    func glassEffect<S: View>(_ style: GlassEffectStyle = .regular, in shape: S) -> ViewNode { self }
    /// `.glassEffect(_:)` — no-op on Clone.
    func glassEffect(_ style: GlassEffectStyle = .regular) -> ViewNode { self }

    /// `.onKeyPress(_:action:)` — no-op on Clone.
    func onKeyPress(_ key: KeyEquivalent, action: @escaping () -> KeyPress.Result) -> ViewNode { self }

    /// `.symbolEffect(_:)` — no-op on Clone.
    func symbolEffect(_ effect: SymbolEffect) -> ViewNode { self }

    /// `.symbolEffect(_:value:)` — no-op on Clone.
    func symbolEffect<V: Equatable>(_ effect: SymbolEffect, value: V) -> ViewNode { self }

    /// `.gridCellUnsizedAxes(_:)` — no-op on Clone.
    func gridCellUnsizedAxes(_ axes: Axis) -> ViewNode { self }

    /// `.strikethrough(_:color:)` — no-op on Clone.
    func strikethrough(_ active: Bool = true, color: Color? = nil) -> ViewNode { self }

    /// `.textContentType(_:)` — no-op on Clone.
    func textContentType(_ type: NSTextContentType?) -> ViewNode { self }

    /// `.rotation3DEffect(_:axis:)` — no-op on Clone.
    func rotation3DEffect(_ angle: Angle, axis: (x: CGFloat, y: CGFloat, z: CGFloat)) -> ViewNode { self }

    /// `.rotation3DEffect(_:axis:anchor:anchorZ:perspective:)` — no-op on Clone.
    func rotation3DEffect(_ angle: Angle, axis: (x: CGFloat, y: CGFloat, z: CGFloat), anchor: UnitPoint = .center, anchorZ: CGFloat = 0, perspective: CGFloat = 1) -> ViewNode { self }

    /// `.labelStyle(_:)` — no-op on Clone.
    func labelStyle<S: LabelStyle>(_ style: S) -> ViewNode { self }

    /// `.listRowBackground(_:)` — no-op for view variant on Clone.
    func listRowBackground<V: View>(_ view: V?) -> ViewNode { self }

    /// `.toolbar(_:)` — toolbar with ToolbarContent.
    func toolbar<C: ToolbarContent>(@ToolbarContentBuilder _ content: () -> C) -> ViewNode { self }

    /// `.toolbar(removing:)` — removes default toolbar items. No-op on Clone.
    func toolbar(removing: ToolbarDefaultItemKind?) -> ViewNode { self }

    /// `.presentationDetents(_:)` — no-op on Clone.
    func presentationDetents(_ detents: Swift.Set<PresentationDetent>) -> ViewNode { self }

    /// `.interactiveDismissDisabled(_:)` — no-op on Clone.
    func interactiveDismissDisabled(_ isDisabled: Bool = true) -> ViewNode { self }

    /// `.matchedGeometryEffect(id:in:)` — no-op on Clone.
    func matchedGeometryEffect(id: some Hashable, in namespace: Namespace.ID) -> ViewNode { self }

    /// `.navigationBarBackButtonHidden(_:)` — no-op on Clone.
    func navigationBarBackButtonHidden(_ hidden: Bool = true) -> ViewNode { self }

    /// `.textSelection(_:)` — no-op on Clone.
    func textSelection(_ selectability: TextSelectability) -> ViewNode { self }

    /// `.onMove(perform:)` — no-op on Clone.
    func onMove(perform: ((IndexSet, Int) -> Void)?) -> ViewNode { self }

    /// `.onDelete(perform:)` — no-op on Clone.
    func onDelete(perform: ((IndexSet) -> Void)?) -> ViewNode { self }

    /// `.progressViewStyle(_:)` — no-op on Clone.
    func progressViewStyle<S: ProgressViewStyle>(_ style: S) -> ViewNode { self }

    /// `.scaleEffect(x:y:)` — no-op on Clone.
    func scaleEffect(x: CGFloat = 1, y: CGFloat = 1) -> ViewNode { self }

    /// `.scaleEffect(x:y:anchor:)` — no-op on Clone.
    func scaleEffect(x: CGFloat = 1, y: CGFloat = 1, anchor: UnitPoint = .center) -> ViewNode { self }

    /// `.scaleEffect(_:anchor:)` — no-op on Clone.
    func scaleEffect(_ scale: CGFloat, anchor: UnitPoint) -> ViewNode { self }

    /// `.fullScreenCover(isPresented:content:)` — no-op on Clone.
    func fullScreenCover(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: () -> some View) -> ViewNode { self }

    /// `.navigationBarTitleDisplayMode(_:)` — no-op on Clone.
    func navigationBarTitleDisplayMode(_ displayMode: NavigationBarItem.TitleDisplayMode) -> ViewNode { self }

    /// `.listRowSeparator(_:)` — no-op on Clone.
    func listRowSeparator(_ visibility: Visibility) -> ViewNode { self }

    /// `.listRowInsets(_:)` — no-op on Clone.
    func listRowInsets(_ insets: EdgeInsets?) -> ViewNode { self }

    /// `.contentMargins(_:_:for:)` — no-op on Clone.
    func contentMargins(_ edges: Edge.Set = .all, _ length: CGFloat, for placement: ContentMarginPlacement = .automatic) -> ViewNode { self }

    /// `.scrollContentBackground(_:)` — no-op on Clone.
    func scrollContentBackground(_ visibility: Visibility) -> ViewNode { self }

    /// `.scrollIndicators(_:)` — no-op on Clone.
    func scrollIndicators(_ visibility: ScrollIndicatorVisibility) -> ViewNode { self }

    /// `.popover(isPresented:content:)` — no-op on Clone.
    func popover(isPresented: Binding<Bool>, arrowEdge: Edge = .top, @ViewBuilder content: () -> some View) -> ViewNode { self }

    /// `.focused(_:equals:)` — no-op on Clone.
    func focused<V: Hashable>(_ binding: Binding<V?>, equals value: V) -> ViewNode { self }

    /// `.focused(_:)` (Bool binding variant) — no-op on Clone.
    func focused(_ condition: Binding<Bool>) -> ViewNode { self }

    /// `.sensoryFeedback(_:trigger:)` — no-op on Clone.
    func sensoryFeedback<V: Equatable>(_ feedback: SensoryFeedback, trigger: V) -> ViewNode { self }

    /// `.defaultFocus(_:_:)` — no-op on Clone.
    func defaultFocus<V: Hashable>(_ binding: Binding<V?>, _ value: V) -> ViewNode { self }

    /// `.focusSection()` — no-op on Clone.
    func focusSection() -> ViewNode { self }

    /// `.headerProminence(_:)` — no-op on Clone.
    func headerProminence(_ prominence: Prominence) -> ViewNode { self }

    /// `.onChange(of:_:)` — Swift 5.9+ onChange with old and new values.
    func onChange<V: Equatable>(of value: V, _ action: @escaping (V, V) -> Void, file: String = #fileID, line: Int = #line) -> ViewNode {
        if let (old, changed) = OnChangeRegistry.shared.track(value: value, file: file, line: line), changed {
            let oldTyped = old as! V
            let newVal = value
            OnChangeRegistry.shared.enqueue { action(oldTyped, newVal) }
        }
        return self
    }

    /// `.disableAutocorrection(_:)` — no-op on Clone.
    func disableAutocorrection(_ disable: Bool?) -> ViewNode { self }

    /// `.autocorrectionDisabled(_:)` — no-op on Clone.
    func autocorrectionDisabled(_ disable: Bool = true) -> ViewNode { self }

    /// `.textCase(_:)` — no-op on Clone.
    func textCase(_ textCase: Text.Case?) -> ViewNode { self }

    /// `.trim(from:to:)` — no-op on Clone.
    func trim(from: CGFloat = 0, to: CGFloat = 1) -> ViewNode { self }

    /// `.mask(content:)` — no-op on Clone.
    func mask<V: View>(@ViewBuilder _ mask: () -> V) -> ViewNode { self }

    /// `.mask(_:)` — direct View variant.
    @MainActor func mask<V: View>(_ mask: V) -> ViewNode { self }

    /// `.controlSize(_:)` — no-op on Clone.
    func controlSize(_ size: ControlSize) -> ViewNode { self }

    /// `.formStyle(_:)` — no-op on Clone.
    func formStyle<S: FormStyle>(_ style: S) -> ViewNode { self }

    /// `.zIndex(_:)` — no-op on Clone.
    func zIndex(_ value: Double) -> ViewNode { self }

    /// `.submitLabel(_:)` — no-op on Clone.
    func submitLabel(_ label: SubmitLabel) -> ViewNode { self }

    /// `.colorScheme(_:)` — no-op on Clone.
    func colorScheme(_ scheme: ColorScheme) -> ViewNode { self }

    /// `.accentColor(_:)` — no-op on Clone.
    func accentColor(_ color: Color?) -> ViewNode { self }

    /// `.navigationSplitViewColumnWidth(_:)` — no-op on Clone.
    func navigationSplitViewColumnWidth(_ width: CGFloat) -> ViewNode { self }

    /// `.navigationSplitViewColumnWidth(min:ideal:max:)` — no-op on Clone.
    func navigationSplitViewColumnWidth(min: CGFloat? = nil, ideal: CGFloat, max: CGFloat? = nil) -> ViewNode { self }

    /// `.onDrop(of:isTargeted:perform:)` — no-op on Clone.
    func onDrop(of types: [UTType], isTargeted: Binding<Bool>?, perform: @escaping ([NSItemProvider]) -> Bool) -> ViewNode { self }

    /// `.clipShape(_:)` with Shape constraint — no-op on Clone.
    func clipShape<S: Shape>(_ shape: S) -> ViewNode { self }

    /// `.textInputAutocapitalization(_:)` — no-op on Clone.
    func textInputAutocapitalization(_ autocapitalization: Any?) -> ViewNode { self }

    /// `.modelContainer(for:)` — no-op on Clone.
    func modelContainer(for modelType: Any.Type, inMemory: Bool = false, isAutosaveEnabled: Bool = true, isUndoEnabled: Bool = false) -> ViewNode { self }

    /// `.modelContainer(for:)` — array variant, no-op on Clone.
    func modelContainer(for modelTypes: [Any.Type], inMemory: Bool = false, isAutosaveEnabled: Bool = true, isUndoEnabled: Bool = false) -> ViewNode { self }

    /// `.accessibilityValue(_:)` — no-op on Clone.
    func accessibilityValue(_ value: String) -> ViewNode { self }

    /// `.accessibilityValue(_:)` — generic variant, no-op on Clone.
    func accessibilityValue<V>(_ value: V) -> ViewNode { self }

    /// `.accessibilityAddTraits(_:)` — no-op on Clone.
    func accessibilityAddTraits(_ traits: AccessibilityTraits) -> ViewNode { self }

    /// `.accessibilityRemoveTraits(_:)` — no-op on Clone.
    func accessibilityRemoveTraits(_ traits: AccessibilityTraits) -> ViewNode { self }

    /// `.accessibilityIdentifier(_:)` — no-op on Clone.
    func accessibilityIdentifier(_ identifier: String) -> ViewNode { self }

    /// `.navigationSplitViewStyle(_:)` — no-op on Clone.
    func navigationSplitViewStyle<S: NavigationSplitViewStyleProtocol>(_ style: S) -> ViewNode { self }

    /// `.accessibilityHint(_:)` — no-op on Clone.
    func accessibilityHint(_ hint: String) -> ViewNode { self }

    /// `.blur(radius:opaque:)` — applies a Gaussian blur. No-op on Clone.
    func blur(radius: CGFloat, opaque: Bool = false) -> ViewNode { self }

    /// `.equatable()` — marks the view for equality-based updates. No-op on Clone.
    func equatable() -> ViewNode { self }

    /// `.fixedSize()` — prevents the view from being compressed below its ideal size.
    func fixedSize() -> ViewNode { self }

    /// `.fixedSize(horizontal:vertical:)` — prevents compression on specified axes.
    func fixedSize(horizontal: Bool = true, vertical: Bool = true) -> ViewNode { self }

    /// `.containerRelativeFrame(_:)` — no-op on Clone.
    func containerRelativeFrame(_ axes: Axis) -> ViewNode { self }

    /// `.containerRelativeFrame(_:alignment:)` — no-op on Clone.
    func containerRelativeFrame(_ axes: Axis, alignment: Alignment) -> ViewNode { self }

    /// `.draggable(_:)` — no-op on Clone.
    func draggable<T>(_ payload: @autoclosure () -> T) -> ViewNode { self }

    /// `.dropDestination(for:action:)` — no-op on Clone.
    func dropDestination<T>(for type: T.Type, action: @escaping ([T], CGPoint) -> Bool) -> ViewNode { self }

    /// `.handlesExternalEvents(preferring:allowing:)` — no-op on Clone.
    func handlesExternalEvents(preferring: Swift.Set<String>, allowing: Swift.Set<String>) -> ViewNode { self }

    /// `.onOpenURL(perform:)` — no-op on Clone.
    func onOpenURL(perform action: @escaping (URL) -> Void) -> ViewNode { self }

    /// `.menuStyle(_:)` — no-op on Clone.
    func menuStyle<S>(_ style: S) -> ViewNode { self }

    /// `.toolbarBackground(_:for:)` — no-op on Clone.
    func toolbarBackground<S>(_ style: S, for bars: ToolbarPlacement...) -> ViewNode { self }

    /// `.toolbarColorScheme(_:for:)` — no-op on Clone.
    func toolbarColorScheme(_ colorScheme: ColorScheme?, for bars: ToolbarPlacement...) -> ViewNode { self }

    /// `.navigationViewStyle(_:)` — no-op on Clone.
    func navigationViewStyle<S>(_ style: S) -> ViewNode { self }

    /// `.focusEffectDisabled(_:)` — no-op on Clone.
    func focusEffectDisabled(_ disabled: Bool = true) -> ViewNode { self }

    /// `.symbolEffect(_:isActive:)` — no-op on Clone.
    func symbolEffect(_ effect: SymbolEffect, isActive: Bool) -> ViewNode { self }

    /// `.onKeyPress(_:action:)` — with KeyPress parameter, no-op on Clone.
    func onKeyPress(_ key: KeyEquivalent, action: @escaping (KeyPress) -> KeyPress.Result) -> ViewNode { self }

}

/// `.background(_:)` — wraps content in a ZStack with a background color behind it.
public extension ViewNode {
    func background(_ color: Color) -> ViewNode {
        .zstack(children: [
            .rect(width: nil, height: nil, fill: color),
            self,
        ])
    }

    /// `.background(_:)` — background with arbitrary view (e.g. LinearGradient).
    @MainActor func background<V: View>(_ view: V) -> ViewNode {
        .zstack(children: [_resolve(view), self])
    }

    /// `.listRowBackground(_:)` — alias for background, matches SwiftUI naming.
    func listRowBackground(_ color: Color) -> ViewNode {
        background(color)
    }
}
