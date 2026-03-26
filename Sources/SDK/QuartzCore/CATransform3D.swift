import Foundation

// MARK: - CATransform3D

/// A 4x4 transformation matrix used for 3D transforms on layers.
public struct CATransform3D: Sendable {
    public var m11: CGFloat = 1, m12: CGFloat = 0, m13: CGFloat = 0, m14: CGFloat = 0
    public var m21: CGFloat = 0, m22: CGFloat = 1, m23: CGFloat = 0, m24: CGFloat = 0
    public var m31: CGFloat = 0, m32: CGFloat = 0, m33: CGFloat = 1, m34: CGFloat = 0
    public var m41: CGFloat = 0, m42: CGFloat = 0, m43: CGFloat = 0, m44: CGFloat = 1
    public init() {}
}

public let CATransform3DIdentity = CATransform3D()

public func CATransform3DRotate(_ t: CATransform3D, _ angle: CGFloat, _ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> CATransform3D { t }
public func CATransform3DTranslate(_ t: CATransform3D, _ tx: CGFloat, _ ty: CGFloat, _ tz: CGFloat) -> CATransform3D { t }
public func CATransform3DScale(_ t: CATransform3D, _ sx: CGFloat, _ sy: CGFloat, _ sz: CGFloat) -> CATransform3D { t }
public func CATransform3DConcat(_ a: CATransform3D, _ b: CATransform3D) -> CATransform3D { a }
public func CATransform3DMakeRotation(_ angle: CGFloat, _ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> CATransform3D { CATransform3D() }
public func CATransform3DMakeTranslation(_ tx: CGFloat, _ ty: CGFloat, _ tz: CGFloat) -> CATransform3D { CATransform3D() }
public func CATransform3DMakeScale(_ sx: CGFloat, _ sy: CGFloat, _ sz: CGFloat) -> CATransform3D { CATransform3D() }
public func CATransform3DIsIdentity(_ t: CATransform3D) -> Bool {
    t.m11 == 1 && t.m12 == 0 && t.m13 == 0 && t.m14 == 0 &&
    t.m21 == 0 && t.m22 == 1 && t.m23 == 0 && t.m24 == 0 &&
    t.m31 == 0 && t.m32 == 0 && t.m33 == 1 && t.m34 == 0 &&
    t.m41 == 0 && t.m42 == 0 && t.m43 == 0 && t.m44 == 1
}
public func CATransform3DEqualToTransform(_ a: CATransform3D, _ b: CATransform3D) -> Bool {
    a.m11 == b.m11 && a.m12 == b.m12 && a.m13 == b.m13 && a.m14 == b.m14 &&
    a.m21 == b.m21 && a.m22 == b.m22 && a.m23 == b.m23 && a.m24 == b.m24 &&
    a.m31 == b.m31 && a.m32 == b.m32 && a.m33 == b.m33 && a.m34 == b.m34 &&
    a.m41 == b.m41 && a.m42 == b.m42 && a.m43 == b.m43 && a.m44 == b.m44
}
