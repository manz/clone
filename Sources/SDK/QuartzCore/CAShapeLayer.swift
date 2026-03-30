import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#else
import CloneCoreGraphics
#endif

// MARK: - CAShapeLayer

open class CAShapeLayer: CALayer {
    open var path: CGPath?
    open var fillColor: CGColor?
    open var fillRule: CAShapeLayerFillRule = .nonZero
    open var strokeColor: CGColor?
    open var strokeStart: CGFloat = 0
    open var strokeEnd: CGFloat = 1
    open var lineWidth: CGFloat = 1
    open var lineCap: CAShapeLayerLineCap = .butt
    open var lineJoin: CAShapeLayerLineJoin = .miter
    open var miterLimit: CGFloat = 10
    open var lineDashPhase: CGFloat = 0
    open var lineDashPattern: [NSNumber]?
}

public struct CAShapeLayerFillRule: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let nonZero = CAShapeLayerFillRule(rawValue: "non-zero")
    public static let evenOdd = CAShapeLayerFillRule(rawValue: "even-odd")
}

public struct CAShapeLayerLineCap: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let butt = CAShapeLayerLineCap(rawValue: "butt")
    public static let round = CAShapeLayerLineCap(rawValue: "round")
    public static let square = CAShapeLayerLineCap(rawValue: "square")
}

public struct CAShapeLayerLineJoin: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let miter = CAShapeLayerLineJoin(rawValue: "miter")
    public static let round = CAShapeLayerLineJoin(rawValue: "round")
    public static let bevel = CAShapeLayerLineJoin(rawValue: "bevel")
}
