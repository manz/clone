import Foundation

// MARK: - SwiftUI-style view constructors

/// `Text("Hello")` — defaults to 14pt, .text color
public func Text(_ content: String) -> ViewNode {
    .text(content, fontSize: 14, color: .text)
}

/// `Color.red` / `Color(.systemBlue)` as a filled rect
public struct Color {
    let color: DesktopColor
    public init(_ color: DesktopColor) { self.color = color }

    public var body: ViewNode {
        .rect(width: nil, height: nil, fill: color)
    }
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
    func foregroundColor(_ color: DesktopColor) -> ViewNode {
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
    func fill(_ color: DesktopColor) -> ViewNode {
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
        color: DesktopColor = DesktopColor(r: 0, g: 0, b: 0, a: 0.3),
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
