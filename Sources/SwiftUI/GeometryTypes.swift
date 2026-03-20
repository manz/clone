import Foundation

/// A modifier that changes the shape of a view by applying a geometric transform.
public protocol GeometryEffect: ViewModifier {
    func effectValue(size: CGSize) -> ProjectionTransform
}

/// A 3x3 matrix for projecting 2D content.
public struct ProjectionTransform {
    public init() {}
}

/// A geometric angle.
public struct Angle: Sendable {
    public var radians: Double
    public var degrees: Double { radians * 180 / .pi }

    public init(radians: Double) { self.radians = radians }
    public init(degrees: Double) { self.radians = degrees * .pi / 180 }

    public static func degrees(_ d: Double) -> Angle { Angle(degrees: d) }
    public static func radians(_ r: Double) -> Angle { Angle(radians: r) }
    public static let zero = Angle(radians: 0)
}

/// The visual characteristics of a stroke.
public struct StrokeStyle: Sendable {
    public var lineWidth: CGFloat
    public var lineCap: LineCap
    public var lineJoin: LineJoin
    public var dash: [CGFloat]

    public init(lineWidth: CGFloat = 1, lineCap: LineCap = .butt, lineJoin: LineJoin = .miter, dash: [CGFloat] = []) {
        self.lineWidth = lineWidth
        self.lineCap = lineCap
        self.lineJoin = lineJoin
        self.dash = dash
    }

    /// The shape of the endpoint of a line.
    public enum LineCap: Sendable { case butt, round, square }
    /// The shape of the junction between connected line segments.
    public enum LineJoin: Sendable { case miter, round, bevel }
}

/// A 2D shape that you can use as part of drawing a view.
public struct Path: View {
    public init() {}
    public init(_ callback: (inout Path) -> Void) { var p = Path(); callback(&p) }

    public mutating func move(to point: CGPoint) {}
    public mutating func addLine(to point: CGPoint) {}
    public mutating func addArc(center: CGPoint, radius: CGFloat, startAngle: Angle, endAngle: Angle, clockwise: Bool) {}
    public mutating func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint) {}
    public mutating func addQuadCurve(to end: CGPoint, control: CGPoint) {}
    public mutating func closeSubpath() {}
    public mutating func addRect(_ rect: CGRect) {}
    public mutating func addRoundedRect(in rect: CGRect, cornerSize: CGSize) {}
    public mutating func addEllipse(in rect: CGRect) {}

    public func stroke(_ color: Color, lineWidth: CGFloat = 1) -> ViewNode { .empty }
    public func stroke(_ color: Color, style: StrokeStyle) -> ViewNode { .empty }
    public func fill(_ color: Color) -> ViewNode { .empty }

    public var body: ViewNode { .empty }
}

/// An ellipse shape.
public struct Ellipse: View {
    public init() {}
    public var body: ViewNode { .roundedRect(width: nil, height: nil, radius: 1000, fill: .white) }

    public func fill(_ color: Color) -> ViewNode { .roundedRect(width: nil, height: nil, radius: 1000, fill: color) }
    public func stroke(_ color: Color, lineWidth: CGFloat = 1) -> ViewNode { .empty }
}
