import Foundation

// MARK: - CAMediaTimingFunctionName

public struct CAMediaTimingFunctionName: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let linear = CAMediaTimingFunctionName(rawValue: "linear")
    public static let easeIn = CAMediaTimingFunctionName(rawValue: "easeIn")
    public static let easeOut = CAMediaTimingFunctionName(rawValue: "easeOut")
    public static let easeInEaseOut = CAMediaTimingFunctionName(rawValue: "easeInEaseOut")
    public static let `default` = CAMediaTimingFunctionName(rawValue: "default")
}

// MARK: - CAMediaTimingFunction

/// A timing function defined by a cubic Bezier curve.
/// The curve maps input time [0,1] to output progress [0,1].
public class CAMediaTimingFunction {

    private let c1x: Float
    private let c1y: Float
    private let c2x: Float
    private let c2y: Float

    public init(name: CAMediaTimingFunctionName) {
        switch name {
        case .linear:
            c1x = 0; c1y = 0; c2x = 1; c2y = 1
        case .easeIn:
            c1x = 0.42; c1y = 0; c2x = 1; c2y = 1
        case .easeOut:
            c1x = 0; c1y = 0; c2x = 0.58; c2y = 1
        case .easeInEaseOut:
            c1x = 0.42; c1y = 0; c2x = 0.58; c2y = 1
        default: // .default
            c1x = 0.25; c1y = 0.1; c2x = 0.25; c2y = 1
        }
    }

    public init(controlPoints c1x: Float, _ c1y: Float, _ c2x: Float, _ c2y: Float) {
        self.c1x = c1x
        self.c1y = c1y
        self.c2x = c2x
        self.c2y = c2y
    }

    public func getControlPoint(at idx: Int, values: UnsafeMutablePointer<Float>) {
        switch idx {
        case 0: values[0] = 0; values[1] = 0
        case 1: values[0] = c1x; values[1] = c1y
        case 2: values[0] = c2x; values[1] = c2y
        case 3: values[0] = 1; values[1] = 1
        default: break
        }
    }

    /// Evaluate the timing function at a given linear time t in [0,1].
    /// Returns the eased progress value.
    public func evaluate(at t: Float) -> Float {
        // Cubic bezier: B(t) = 3(1-t)^2*t*P1 + 3(1-t)*t^2*P2 + t^3
        // We need to solve for the parameter that gives us x=t, then return y.
        // Use Newton-Raphson to find the bezier parameter for the given x.
        let parameter = solveCurveX(t)
        return bezierY(parameter)
    }

    private func bezierX(_ t: Float) -> Float {
        let mt = 1 - t
        return 3 * mt * mt * t * c1x + 3 * mt * t * t * c2x + t * t * t
    }

    private func bezierY(_ t: Float) -> Float {
        let mt = 1 - t
        return 3 * mt * mt * t * c1y + 3 * mt * t * t * c2y + t * t * t
    }

    private func bezierXDerivative(_ t: Float) -> Float {
        let mt = 1 - t
        return 3 * mt * mt * c1x + 6 * mt * t * (c2x - c1x) + 3 * t * t * (1 - c2x)
    }

    private func solveCurveX(_ x: Float) -> Float {
        // Newton-Raphson
        var t = x
        for _ in 0..<8 {
            let xEst = bezierX(t) - x
            let dx = bezierXDerivative(t)
            if abs(dx) < 1e-6 { break }
            t -= xEst / dx
        }
        return min(max(t, 0), 1)
    }
}

// MARK: - CAMediaTiming

public protocol CAMediaTiming {
    var beginTime: CFTimeInterval { get set }
    var duration: CFTimeInterval { get set }
    var speed: Float { get set }
    var timeOffset: CFTimeInterval { get set }
    var repeatCount: Float { get set }
    var repeatDuration: CFTimeInterval { get set }
    var autoreverses: Bool { get set }
    var fillMode: CAMediaTimingFillMode { get set }
}

public struct CAMediaTimingFillMode: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let removed = CAMediaTimingFillMode(rawValue: "removed")
    public static let forwards = CAMediaTimingFillMode(rawValue: "forwards")
    public static let backwards = CAMediaTimingFillMode(rawValue: "backwards")
    public static let both = CAMediaTimingFillMode(rawValue: "both")
}
