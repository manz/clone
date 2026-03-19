import Foundation

// MARK: - SwiftUI-style view constructors

/// `Text("Hello")` — defaults to 14pt, .text color
public func Text(_ content: String) -> ViewNode {
    .text(content, fontSize: 14, color: .text)
}

/// `Rectangle()` — solid filled rect
public func Rectangle() -> ViewNode {
    .rect(width: nil, height: nil, fill: .white)
}

/// `RoundedRectangle(cornerRadius: 12)`
public func RoundedRectangle(cornerRadius: Float) -> ViewNode {
    .roundedRect(width: nil, height: nil, radius: cornerRadius, fill: .white)
}

/// `Spacer()`
public func Spacer(minLength: Float = 0) -> ViewNode {
    .spacer(minLength: minLength)
}

/// `VStack { ... }`
public func VStack(
    alignment: HAlignment = .center,
    spacing: Float = 8,
    @ViewBuilder content: () -> [ViewNode]
) -> ViewNode {
    .vstack(alignment: alignment, spacing: spacing, children: content())
}

/// `HStack { ... }`
public func HStack(
    alignment: VAlignment = .center,
    spacing: Float = 8,
    @ViewBuilder content: () -> [ViewNode]
) -> ViewNode {
    .hstack(alignment: alignment, spacing: spacing, children: content())
}

/// `ZStack { ... }`
public func ZStack(@ViewBuilder content: () -> [ViewNode]) -> ViewNode {
    .zstack(children: content())
}

// MARK: - Button

/// `Button("Tap") { action }` — label string variant
public func Button(_ label: String, action: @escaping () -> Void) -> ViewNode {
    Text(label)
        .foregroundColor(.systemBlue)
        .onTapGesture(action)
}

/// `Button(action: { }) { label }` — custom label variant
public func Button(action: @escaping () -> Void, @ViewBuilder label: () -> [ViewNode]) -> ViewNode {
    let content = label()
    let child = content.count == 1 ? content[0] : ViewNode.hstack(alignment: .center, spacing: 4, children: content)
    return child.onTapGesture(action)
}

// MARK: - ScrollView / List

/// `ScrollView { ... }` — vertical by default. Renders as VStack until scrolling is implemented.
public func ScrollView(
    _ axis: Axis = .vertical,
    @ViewBuilder content: () -> [ViewNode]
) -> ViewNode {
    .scrollView(axis: axis, children: content())
}

/// `List { ... }` — renders as VStack with dividers between children.
public func List(@ViewBuilder content: () -> [ViewNode]) -> ViewNode {
    .list(children: content())
}

// MARK: - Image

/// `Image(systemName:)` — stub: renders as a colored placeholder rect.
public func Image(systemName: String) -> ViewNode {
    .image(name: systemName, width: nil, height: nil)
}

/// `Image(_:)` — named image stub.
public func Image(_ name: String) -> ViewNode {
    .image(name: name, width: nil, height: nil)
}

// MARK: - Form controls

/// `Toggle(isOn:) { label }` — renders static representation.
public func Toggle(isOn: Binding<Bool>, @ViewBuilder label: () -> [ViewNode]) -> ViewNode {
    let labelNode = label().count == 1 ? label()[0] : ViewNode.hstack(alignment: .center, spacing: 4, children: label())
    return .toggle(isOn: isOn.wrappedValue, label: labelNode)
}

/// `Toggle("Label", isOn:)` — convenience.
public func Toggle(_ title: String, isOn: Binding<Bool>) -> ViewNode {
    .toggle(isOn: isOn.wrappedValue, label: Text(title))
}

/// `Slider(value:in:)` — renders static track + knob.
public func Slider(value: Binding<Float>, in range: ClosedRange<Float> = 0...1) -> ViewNode {
    .slider(value: value.wrappedValue, range: range, label: .empty)
}

/// `Picker(selection:) { options } label: { label }` — renders label + current value.
public func Picker(
    _ title: String,
    selection: Binding<String>,
    @ViewBuilder content: () -> [ViewNode]
) -> ViewNode {
    .picker(selection: selection.wrappedValue, label: Text(title), children: content())
}

/// `TextField("Placeholder", text:)` — text input box with placeholder.
public func TextField(_ placeholder: String, text: Binding<String>) -> ViewNode {
    .textField(placeholder: placeholder, text: text.wrappedValue)
}

// MARK: - Navigation

/// `NavigationStack { ... }` — wraps children in a VStack (navigation state is window-managed).
public func NavigationStack(@ViewBuilder content: () -> [ViewNode]) -> ViewNode {
    .navigationStack(children: content())
}

// MARK: - Menu

/// `Menu("Label") { ... }` — collapsed menu with children.
public func Menu(_ label: String, @ViewBuilder content: () -> [ViewNode]) -> ViewNode {
    .menu(label: label, children: content())
}

// MARK: - Modifier chains on ViewNode

public extension ViewNode {

    /// `.frame(width: 200, height: 100)`
    func frame(width: Float? = nil, height: Float? = nil) -> ViewNode {
        .frame(width: width, height: height, child: self)
    }

    /// `.frame(maxWidth: .infinity)` — fills available space
    func frame(maxWidth: Float? = nil, maxHeight: Float? = nil) -> ViewNode {
        .frame(width: maxWidth, height: maxHeight, child: self)
    }

    /// `.padding(16)` — uniform padding
    func padding(_ value: Float) -> ViewNode {
        .padding(EdgeInsets(all: value), child: self)
    }

    /// `.padding(.horizontal, 16)`
    func padding(_ edges: Edge.Set, _ value: Float) -> ViewNode {
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

    /// `.opacity(0.5)`
    func opacity(_ value: Float) -> ViewNode {
        .opacity(value, child: self)
    }

    /// `.foregroundColor(.white)` — only meaningful for text nodes, wraps as-is for others
    func foregroundColor(_ color: Color) -> ViewNode {
        switch self {
        case .text(let content, let fontSize, _, let weight):
            return .text(content, fontSize: fontSize, color: color, weight: weight)
        default:
            return self
        }
    }

    /// `.fontSize(24)`
    func fontSize(_ size: Float) -> ViewNode {
        switch self {
        case .text(let content, _, let color, let weight):
            return .text(content, fontSize: size, color: color, weight: weight)
        default:
            return self
        }
    }

    /// `.bold()`
    func bold() -> ViewNode {
        fontWeight(.bold)
    }

    /// `.fontWeight(.semibold)`
    func fontWeight(_ weight: FontWeight) -> ViewNode {
        switch self {
        case .text(let content, let fontSize, let color, _):
            return .text(content, fontSize: fontSize, color: color, weight: weight)
        default:
            return self
        }
    }

    /// `.font(.system(size:))` — SwiftUI-ish
    func font(size: Float) -> ViewNode {
        fontSize(size)
    }

    /// `.fill(.systemBlue)` — sets the fill color on rect/roundedRect
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
    func cornerRadius(_ radius: Float) -> ViewNode {
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
        radius: Float = 10,
        x: Float = 0,
        y: Float = 2
    ) -> ViewNode {
        .shadow(radius: radius, blur: radius, color: color, offsetX: x, offsetY: y, child: self)
    }

    /// `.onTapGesture { }` — registers a closure and attaches its ID
    func onTapGesture(_ handler: @escaping () -> Void) -> ViewNode {
        let id = TapRegistry.shared.register(handler)
        return .onTap(id: id, child: self)
    }

    /// `.onTapGesture(id:)` — attaches a pre-existing tap ID
    func onTapGesture(id: UInt64) -> ViewNode {
        .onTap(id: id, child: self)
    }

    /// `.clipped()` — clips content to this view's frame.
    func clipped(radius: Float = 0) -> ViewNode {
        .clipped(radius: radius, child: self)
    }

    /// `.contextMenu { }` — attaches a context menu to this view.
    func contextMenu(@ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        .contextMenu(child: self, menuItems: content())
    }

    /// `.navigationTitle(_:)` — no-op for now (window title is set by the compositor).
    func navigationTitle(_ title: String) -> ViewNode {
        self
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
    func clipShape(_ shape: ViewNode) -> ViewNode {
        self
    }
}

// MARK: - SwiftUI-compatible compound views

/// `Label("Wi-Fi", systemImage: "wifi")` — icon rounded rect + text, like SwiftUI Label.
/// Since we don't have SF Symbols, `systemImage` is ignored visually but the icon color is used.
public func Label(_ title: String, systemImage: String, iconColor: Color = .systemBlue) -> ViewNode {
    .hstack(alignment: .center, spacing: 8, children: [
        .roundedRect(width: 20, height: 20, radius: 5, fill: iconColor),
        .text(title, fontSize: 13, color: .text),
    ])
}

/// `Divider()` — 1px horizontal line
public func Divider() -> ViewNode {
    .rect(width: nil, height: 1, fill: .overlay)
}

/// `Section("Header") { ... }` — grouped rows with optional header, like SwiftUI Section.
public func Section(
    _ header: String? = nil,
    @ViewBuilder content: () -> [ViewNode]
) -> ViewNode {
    var children: [ViewNode] = []
    if let header {
        children.append(
            ViewNode.text(header, fontSize: 12, color: .subtle, weight: .semibold)
        )
    }
    let rows = content()
    // Interleave rows with dividers
    for (i, row) in rows.enumerated() {
        children.append(row)
        if i < rows.count - 1 {
            children.append(
                ViewNode.rect(width: nil, height: 1, fill: .overlay)
                    .padding(.leading, 12)
            )
        }
    }
    return .vstack(alignment: .leading, spacing: 0, children: children)
}

/// `NavigationSplitView { sidebar } detail: { detail }` — sidebar + detail layout.
public func NavigationSplitView(
    sidebarWidth: Float = 220,
    @ViewBuilder sidebar: () -> [ViewNode],
    @ViewBuilder detail: () -> [ViewNode]
) -> ViewNode {
    .hstack(alignment: .top, spacing: 0, children: [
        ViewNode.vstack(alignment: .leading, spacing: 0, children: sidebar()),
        ViewNode.rect(width: 1, height: nil, fill: .overlay),
        ViewNode.vstack(alignment: .leading, spacing: 0, children: detail()),
    ])
}

/// `ForEach(items) { item in ... }` — maps a collection to ViewNodes.
public func ForEach<T>(_ data: [T], @ViewBuilder content: (T) -> [ViewNode]) -> [ViewNode] {
    data.flatMap { content($0) }
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

// MARK: - Edge.Set for padding

public enum Edge {
    case top, leading, bottom, trailing

    public struct Set: OptionSet, Sendable {
        public let rawValue: UInt8
        public init(rawValue: UInt8) { self.rawValue = rawValue }

        public static let top = Set(rawValue: 1 << 0)
        public static let leading = Set(rawValue: 1 << 1)
        public static let bottom = Set(rawValue: 1 << 2)
        public static let trailing = Set(rawValue: 1 << 3)

        public static let horizontal: Set = [.leading, .trailing]
        public static let vertical: Set = [.top, .bottom]
        public static let all: Set = [.top, .leading, .bottom, .trailing]
    }
}
