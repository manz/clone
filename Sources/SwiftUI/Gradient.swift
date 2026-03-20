import Foundation

/// A color gradient.
public struct Gradient: Sendable {
    /// A color stop in a gradient.
    public struct Stop: Sendable {
        public let color: Color
        public let location: CGFloat
        public init(color: Color, location: CGFloat) { self.color = color; self.location = location }
    }

    public let stops: [Stop]

    public init(colors: [Color]) {
        let count = max(colors.count - 1, 1)
        self.stops = colors.enumerated().map { Stop(color: $0.element, location: CGFloat($0.offset) / CGFloat(count)) }
    }

    public init(stops: [Stop]) { self.stops = stops }
}

/// A linear gradient. Renders as a flat color until gradient rendering is implemented.
public struct LinearGradient: View {
    let gradient: Gradient
    public init(gradient: Gradient, startPoint: UnitPoint, endPoint: UnitPoint) { self.gradient = gradient }
    public init(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint) { self.gradient = Gradient(colors: colors) }
    public init(stops: [Gradient.Stop], startPoint: UnitPoint, endPoint: UnitPoint) { self.gradient = Gradient(stops: stops) }
    public var body: ViewNode {
        .rect(width: nil, height: nil, fill: gradient.stops.first?.color ?? .clear)
    }
}

/// A radial gradient. Renders as a flat color until gradient rendering is implemented.
public struct RadialGradient: View {
    let gradient: Gradient
    public init(gradient: Gradient, center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) { self.gradient = gradient }
    public init(colors: [Color], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) { self.gradient = Gradient(colors: colors) }
    public var body: ViewNode {
        .rect(width: nil, height: nil, fill: gradient.stops.first?.color ?? .clear)
    }
}

/// An angular (conic) gradient. Renders as a flat color until gradient rendering is implemented.
public struct AngularGradient: View {
    let gradient: Gradient
    public init(gradient: Gradient, center: UnitPoint) { self.gradient = gradient }
    public init(colors: [Color], center: UnitPoint) { self.gradient = Gradient(colors: colors) }
    public var body: ViewNode {
        .rect(width: nil, height: nil, fill: gradient.stops.first?.color ?? .clear)
    }
}

/// A point in a view's coordinate space, normalized to [0, 1].
public struct UnitPoint: Sendable, Equatable {
    public let x: CGFloat
    public let y: CGFloat
    public init(x: CGFloat, y: CGFloat) { self.x = x; self.y = y }

    public static let zero = UnitPoint(x: 0, y: 0)
    public static let center = UnitPoint(x: 0.5, y: 0.5)
    public static let leading = UnitPoint(x: 0, y: 0.5)
    public static let trailing = UnitPoint(x: 1, y: 0.5)
    public static let top = UnitPoint(x: 0.5, y: 0)
    public static let bottom = UnitPoint(x: 0.5, y: 1)
    public static let topLeading = UnitPoint(x: 0, y: 0)
    public static let topTrailing = UnitPoint(x: 1, y: 0)
    public static let bottomLeading = UnitPoint(x: 0, y: 1)
    public static let bottomTrailing = UnitPoint(x: 1, y: 1)
}
