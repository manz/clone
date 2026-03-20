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

    /// `.foregroundColor(.white)` — only meaningful for text nodes, wraps as-is for others
    func foregroundColor(_ color: Color) -> ViewNode {
        switch self {
        case .text(let content, let fontSize, _, let weight):
            return .text(content, fontSize: fontSize, color: color, weight: weight)
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
