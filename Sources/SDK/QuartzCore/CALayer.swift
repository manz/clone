import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#else
import CloneCoreGraphics
#endif

// MARK: - CALayerContentsGravity

public struct CALayerContentsGravity: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let center = CALayerContentsGravity(rawValue: "center")
    public static let top = CALayerContentsGravity(rawValue: "top")
    public static let bottom = CALayerContentsGravity(rawValue: "bottom")
    public static let left = CALayerContentsGravity(rawValue: "left")
    public static let right = CALayerContentsGravity(rawValue: "right")
    public static let topLeft = CALayerContentsGravity(rawValue: "topLeft")
    public static let topRight = CALayerContentsGravity(rawValue: "topRight")
    public static let bottomLeft = CALayerContentsGravity(rawValue: "bottomLeft")
    public static let bottomRight = CALayerContentsGravity(rawValue: "bottomRight")
    public static let resize = CALayerContentsGravity(rawValue: "resize")
    public static let resizeAspect = CALayerContentsGravity(rawValue: "resizeAspect")
    public static let resizeAspectFill = CALayerContentsGravity(rawValue: "resizeAspectFill")
}

// MARK: - CALayerCornerCurve

public struct CALayerCornerCurve: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let circular = CALayerCornerCurve(rawValue: "circular")
    public static let continuous = CALayerCornerCurve(rawValue: "continuous")
}

// MARK: - CALayerDelegate

public protocol CALayerDelegate: AnyObject {
    func display(_ layer: CALayer)
    func draw(_ layer: CALayer, in ctx: CGContext)
    func layerWillDraw(_ layer: CALayer)
    func layoutSublayers(of layer: CALayer)
    func action(for layer: CALayer, forKey event: String) -> CAAction?
}

extension CALayerDelegate {
    public func display(_ layer: CALayer) {}
    public func draw(_ layer: CALayer, in ctx: CGContext) {}
    public func layerWillDraw(_ layer: CALayer) {}
    public func layoutSublayers(of layer: CALayer) {}
    public func action(for layer: CALayer, forKey event: String) -> CAAction? { nil }
}

// MARK: - CAAction

public protocol CAAction {
    func run(forKey event: String, object anObject: Any, arguments dict: [String: Any]?)
}

// MARK: - CALayer

open class CALayer {

    // MARK: Geometry

    open var bounds: CGRect = .zero
    open var position: CGPoint = .zero
    open var anchorPoint: CGPoint = CGPoint(x: 0.5, y: 0.5)
    open var zPosition: CGFloat = 0
    open var transform: CATransform3D = CATransform3DIdentity
    open var sublayerTransform: CATransform3D = CATransform3DIdentity

    open var frame: CGRect {
        get {
            let w = bounds.width
            let h = bounds.height
            let x = position.x - w * anchorPoint.x
            let y = position.y - h * anchorPoint.y
            return CGRect(x: x, y: y, width: w, height: h)
        }
        set {
            bounds.size = newValue.size
            position = CGPoint(
                x: newValue.origin.x + newValue.width * anchorPoint.x,
                y: newValue.origin.y + newValue.height * anchorPoint.y
            )
        }
    }

    // MARK: Visual properties

    open var backgroundColor: CGColor?
    open var cornerRadius: CGFloat = 0
    open var cornerCurve: CALayerCornerCurve = .circular
    open var maskedCorners: CACornerMask = .all
    open var borderWidth: CGFloat = 0
    open var borderColor: CGColor?
    open var opacity: Float = 1.0
    open var isHidden: Bool = false
    open var masksToBounds: Bool = false
    open var isDoubleSided: Bool = true
    open var isGeometryFlipped: Bool = false

    // MARK: Shadow

    open var shadowColor: CGColor?
    open var shadowOpacity: Float = 0
    open var shadowOffset: CGSize = CGSize(width: 0, height: -3)
    open var shadowRadius: CGFloat = 3
    open var shadowPath: CGPath?

    // MARK: Contents

    open var contents: Any?
    open var contentsGravity: CALayerContentsGravity = .resize
    open var contentsScale: CGFloat = 1.0
    open var contentsRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    open var contentsCenter: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)

    // MARK: Mask

    open var mask: CALayer?

    // MARK: Layer tree

    open private(set) var sublayers: [CALayer]?
    open private(set) weak var superlayer: CALayer?

    open var name: String?
    open weak var delegate: CALayerDelegate?

    // MARK: Display

    private var _needsDisplay: Bool = true
    private var _needsLayout: Bool = true

    // MARK: Init

    public init() {}

    public init(layer: Any) {
        if let other = layer as? CALayer {
            bounds = other.bounds
            position = other.position
            anchorPoint = other.anchorPoint
            zPosition = other.zPosition
            transform = other.transform
            opacity = other.opacity
            isHidden = other.isHidden
            cornerRadius = other.cornerRadius
            masksToBounds = other.masksToBounds
            backgroundColor = other.backgroundColor
            borderWidth = other.borderWidth
            borderColor = other.borderColor
            shadowColor = other.shadowColor
            shadowOpacity = other.shadowOpacity
            shadowOffset = other.shadowOffset
            shadowRadius = other.shadowRadius
            contentsScale = other.contentsScale
            contentsGravity = other.contentsGravity
            name = other.name
        }
    }

    // MARK: Sublayer management

    open func addSublayer(_ layer: CALayer) {
        layer.removeFromSuperlayer()
        if sublayers == nil { sublayers = [] }
        sublayers!.append(layer)
        layer.superlayer = self
    }

    open func insertSublayer(_ layer: CALayer, at idx: UInt32) {
        layer.removeFromSuperlayer()
        if sublayers == nil { sublayers = [] }
        sublayers!.insert(layer, at: min(Int(idx), sublayers!.count))
        layer.superlayer = self
    }

    open func insertSublayer(_ layer: CALayer, below sibling: CALayer?) {
        layer.removeFromSuperlayer()
        if sublayers == nil { sublayers = [] }
        if let sibling, let idx = sublayers!.firstIndex(where: { $0 === sibling }) {
            sublayers!.insert(layer, at: idx)
        } else {
            sublayers!.append(layer)
        }
        layer.superlayer = self
    }

    open func insertSublayer(_ layer: CALayer, above sibling: CALayer?) {
        layer.removeFromSuperlayer()
        if sublayers == nil { sublayers = [] }
        if let sibling, let idx = sublayers!.firstIndex(where: { $0 === sibling }) {
            sublayers!.insert(layer, at: idx + 1)
        } else {
            sublayers!.append(layer)
        }
        layer.superlayer = self
    }

    open func replaceSublayer(_ oldLayer: CALayer, with newLayer: CALayer) {
        guard let idx = sublayers?.firstIndex(where: { $0 === oldLayer }) else { return }
        newLayer.removeFromSuperlayer()
        sublayers![idx] = newLayer
        oldLayer.superlayer = nil
        newLayer.superlayer = self
    }

    open func removeFromSuperlayer() {
        guard let parent = superlayer else { return }
        parent.sublayers?.removeAll(where: { $0 === self })
        if parent.sublayers?.isEmpty == true { parent.sublayers = nil }
        superlayer = nil
    }

    // MARK: Display cycle

    open func setNeedsDisplay() {
        _needsDisplay = true
    }

    open func displayIfNeeded() {
        guard _needsDisplay else { return }
        _needsDisplay = false
        display()
    }

    open func display() {
        delegate?.display(self)
    }

    open func draw(in ctx: CGContext) {
        delegate?.draw(self, in: ctx)
    }

    open var needsDisplay: Bool { _needsDisplay }

    open class func needsDisplay(forKey key: String) -> Bool { false }

    // MARK: Layout

    open func setNeedsLayout() {
        _needsLayout = true
    }

    open func layoutIfNeeded() {
        guard _needsLayout else { return }
        _needsLayout = false
        layoutSublayers()
    }

    open func layoutSublayers() {
        delegate?.layoutSublayers(of: self)
    }

    open var needsLayout: Bool { _needsLayout }

    // MARK: Hit testing

    open func hitTest(_ p: CGPoint) -> CALayer? {
        guard !isHidden, opacity > 0 else { return nil }
        guard frame.contains(p) else { return nil }
        let local = CGPoint(x: p.x - frame.origin.x, y: p.y - frame.origin.y)
        if let subs = sublayers {
            for layer in subs.reversed() {
                if let hit = layer.hitTest(local) { return hit }
            }
        }
        return self
    }

    open func contains(_ p: CGPoint) -> Bool {
        bounds.contains(p)
    }

    // MARK: Coordinate conversion

    open func convert(_ point: CGPoint, from layer: CALayer?) -> CGPoint {
        guard let layer else { return point }
        let fromOrigin = layer.frame.origin
        let toOrigin = frame.origin
        return CGPoint(x: point.x + fromOrigin.x - toOrigin.x,
                       y: point.y + fromOrigin.y - toOrigin.y)
    }

    open func convert(_ point: CGPoint, to layer: CALayer?) -> CGPoint {
        guard let layer else { return point }
        let fromOrigin = frame.origin
        let toOrigin = layer.frame.origin
        return CGPoint(x: point.x + fromOrigin.x - toOrigin.x,
                       y: point.y + fromOrigin.y - toOrigin.y)
    }

    open func convert(_ rect: CGRect, from layer: CALayer?) -> CGRect {
        let origin = convert(rect.origin, from: layer)
        return CGRect(origin: origin, size: rect.size)
    }

    open func convert(_ rect: CGRect, to layer: CALayer?) -> CGRect {
        let origin = convert(rect.origin, to: layer)
        return CGRect(origin: origin, size: rect.size)
    }

    // MARK: Rendering

    open func render(in ctx: CGContext) {
        draw(in: ctx)
        guard let subs = sublayers else { return }
        for sub in subs {
            sub.render(in: ctx)
        }
    }

    // MARK: Animation (Phase 4 — stubs for now)

    open func add(_ anim: CAAnimation, forKey key: String?) {}
    open func removeAllAnimations() {}
    open func removeAnimation(forKey key: String) {}
    open func animation(forKey key: String) -> CAAnimation? { nil }
    open func animationKeys() -> [String]? { nil }

    // MARK: Presentation

    open func presentation() -> CALayer? { nil }
    open func model() -> CALayer { self }
}

// MARK: - CACornerMask

public struct CACornerMask: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }

    public static let layerMinXMinYCorner = CACornerMask(rawValue: 1 << 0)
    public static let layerMaxXMinYCorner = CACornerMask(rawValue: 1 << 1)
    public static let layerMinXMaxYCorner = CACornerMask(rawValue: 1 << 2)
    public static let layerMaxXMaxYCorner = CACornerMask(rawValue: 1 << 3)

    public static let all: CACornerMask = [
        .layerMinXMinYCorner, .layerMaxXMinYCorner,
        .layerMinXMaxYCorner, .layerMaxXMaxYCorner
    ]
}
