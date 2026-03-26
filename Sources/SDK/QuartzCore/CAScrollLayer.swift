import Foundation

// MARK: - CAScrollLayer

open class CAScrollLayer: CALayer {
    open var scrollMode: CAScrollLayerScrollMode = .both

    open func scroll(to point: CGPoint) {
        bounds.origin = point
    }

    open func scroll(to rect: CGRect) {
        bounds.origin = rect.origin
    }
}

public struct CAScrollLayerScrollMode: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let none = CAScrollLayerScrollMode(rawValue: "none")
    public static let vertically = CAScrollLayerScrollMode(rawValue: "vertically")
    public static let horizontally = CAScrollLayerScrollMode(rawValue: "horizontally")
    public static let both = CAScrollLayerScrollMode(rawValue: "both")
}
