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

    func clipped(radius: CGFloat = 0) -> ViewNode {
        _resolve(self).clipped(radius: radius)
    }

    func navigationTitle(_ title: String) -> ViewNode {
        _resolve(self).navigationTitle(title)
    }

    func background(_ color: Color) -> ViewNode {
        _resolve(self).background(color)
    }
}
