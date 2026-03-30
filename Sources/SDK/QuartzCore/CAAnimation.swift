import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#else
import CloneCoreGraphics
#endif

// MARK: - CAAnimation

/// Base animation class. API-compatible stubs — real animation engine comes in Phase 4.
open class CAAnimation: CAMediaTiming {
    open var beginTime: CFTimeInterval = 0
    open var duration: CFTimeInterval = 0
    open var speed: Float = 1.0
    open var timeOffset: CFTimeInterval = 0
    open var repeatCount: Float = 0
    open var repeatDuration: CFTimeInterval = 0
    open var autoreverses: Bool = false
    open var fillMode: CAMediaTimingFillMode = .removed

    open var timingFunction: CAMediaTimingFunction?
    open var delegate: CAAnimationDelegate?
    open var isRemovedOnCompletion: Bool = true

    public init() {}
}

// MARK: - CAAnimationDelegate

public protocol CAAnimationDelegate: AnyObject {
    func animationDidStart(_ anim: CAAnimation)
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool)
}

extension CAAnimationDelegate {
    public func animationDidStart(_ anim: CAAnimation) {}
    public func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {}
}

// MARK: - CAPropertyAnimation

open class CAPropertyAnimation: CAAnimation {
    open var keyPath: String?
    open var isAdditive: Bool = false
    open var isCumulative: Bool = false

    public convenience init(keyPath: String?) {
        self.init()
        self.keyPath = keyPath
    }
}

// MARK: - CABasicAnimation

open class CABasicAnimation: CAPropertyAnimation {
    open var fromValue: Any?
    open var toValue: Any?
    open var byValue: Any?
}

// MARK: - CAKeyframeAnimation

open class CAKeyframeAnimation: CAPropertyAnimation {
    open var values: [Any]?
    open var keyTimes: [NSNumber]?
    open var path: CGPath?
    open var timingFunctions: [CAMediaTimingFunction]?
    open var calculationMode: CAAnimationCalculationMode = .linear
    open var rotationMode: CAAnimationRotationMode?
    open var tensionValues: [NSNumber]?
    open var continuityValues: [NSNumber]?
    open var biasValues: [NSNumber]?
}

public struct CAAnimationCalculationMode: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let linear = CAAnimationCalculationMode(rawValue: "linear")
    public static let discrete = CAAnimationCalculationMode(rawValue: "discrete")
    public static let paced = CAAnimationCalculationMode(rawValue: "paced")
    public static let cubic = CAAnimationCalculationMode(rawValue: "cubic")
    public static let cubicPaced = CAAnimationCalculationMode(rawValue: "cubicPaced")
}

public struct CAAnimationRotationMode: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let rotateAuto = CAAnimationRotationMode(rawValue: "rotateAuto")
    public static let rotateAutoReverse = CAAnimationRotationMode(rawValue: "rotateAutoReverse")
}

// MARK: - CASpringAnimation

open class CASpringAnimation: CABasicAnimation {
    open var mass: CGFloat = 1
    open var stiffness: CGFloat = 100
    open var damping: CGFloat = 10
    open var initialVelocity: CGFloat = 0

    open var settlingDuration: CFTimeInterval {
        // Approximate settling time for underdamped spring
        let dampingRatio = damping / (2 * sqrt(stiffness * mass))
        if dampingRatio >= 1 { return 1.0 }
        return CFTimeInterval(-log(0.001) / (dampingRatio * sqrt(stiffness / mass)))
    }
}

// MARK: - CAAnimationGroup

open class CAAnimationGroup: CAAnimation {
    open var animations: [CAAnimation]?
}

// MARK: - CATransition

open class CATransition: CAAnimation {
    open var type: CATransitionType = .fade
    open var subtype: CATransitionSubtype?
    open var startProgress: Float = 0
    open var endProgress: Float = 1
}

public struct CATransitionType: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let fade = CATransitionType(rawValue: "fade")
    public static let moveIn = CATransitionType(rawValue: "moveIn")
    public static let push = CATransitionType(rawValue: "push")
    public static let reveal = CATransitionType(rawValue: "reveal")
}

public struct CATransitionSubtype: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let fromRight = CATransitionSubtype(rawValue: "fromRight")
    public static let fromLeft = CATransitionSubtype(rawValue: "fromLeft")
    public static let fromTop = CATransitionSubtype(rawValue: "fromTop")
    public static let fromBottom = CATransitionSubtype(rawValue: "fromBottom")
}
