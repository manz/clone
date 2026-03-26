import Foundation

// MARK: - CAGradientLayer

open class CAGradientLayer: CALayer {
    open var colors: [Any]?            // [CGColor]
    open var locations: [NSNumber]?
    open var startPoint: CGPoint = CGPoint(x: 0.5, y: 0)
    open var endPoint: CGPoint = CGPoint(x: 0.5, y: 1)
    open var type: CAGradientLayerType = .axial
}

public struct CAGradientLayerType: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let axial = CAGradientLayerType(rawValue: "axial")
    public static let radial = CAGradientLayerType(rawValue: "radial")
    public static let conic = CAGradientLayerType(rawValue: "conic")
}
