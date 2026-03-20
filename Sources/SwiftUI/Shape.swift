import Foundation

/// A 2D shape that can be used as a View.
public protocol Shape: View {
    func path(in rect: LayoutFrame) -> ViewNode
    func path(in rect: CGRect) -> Path
}

extension Shape {
    public var body: ViewNode {
        path(in: LayoutFrame(x: 0, y: 0, width: 0, height: 0))
    }

    /// Default implementation so existing shapes don't break.
    public func path(in rect: CGRect) -> Path {
        Path()
    }
}

/// A circle shape.
public struct CircleShape: Shape {
    public init() {}

    public func path(in rect: LayoutFrame) -> ViewNode {
        let size = min(rect.width, rect.height)
        return .roundedRect(width: size, height: size, radius: size / 2, fill: .white)
    }

    public func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addEllipse(in: rect)
        return p
    }

    public var body: ViewNode {
        .roundedRect(width: nil, height: nil, radius: 1000, fill: .white)
    }
}

/// Free function matching SwiftUI API.
public func Circle() -> ViewNode {
    .roundedRect(width: nil, height: nil, radius: 1000, fill: .white)
}

/// A capsule shape (fully rounded ends).
public struct CapsuleShape: Shape {
    public init() {}

    public func path(in rect: LayoutFrame) -> ViewNode {
        let radius = min(rect.width, rect.height) / 2
        return .roundedRect(width: rect.width, height: rect.height, radius: radius, fill: .white)
    }

    public var body: ViewNode {
        .roundedRect(width: nil, height: nil, radius: 1000, fill: .white)
    }
}

/// Free function matching SwiftUI API.
public func Capsule() -> ViewNode {
    .roundedRect(width: nil, height: nil, radius: 1000, fill: .white)
}

/// A rectangle shape (already exists as a free function in ViewDSL).
public struct RectangleShape: Shape {
    public init() {}

    public func path(in rect: LayoutFrame) -> ViewNode {
        .rect(width: rect.width, height: rect.height, fill: .white)
    }

    public var body: ViewNode {
        .rect(width: nil, height: nil, fill: .white)
    }
}

/// A rounded rectangle shape (already exists as a free function in ViewDSL).
public struct RoundedRectangleShape: Shape {
    public let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
    }

    public func path(in rect: LayoutFrame) -> ViewNode {
        .roundedRect(width: rect.width, height: rect.height, radius: cornerRadius, fill: .white)
    }

    public var body: ViewNode {
        .roundedRect(width: nil, height: nil, radius: cornerRadius, fill: .white)
    }
}
