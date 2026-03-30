// CloneCoreGraphics — Linux implementation of CoreGraphics types.
//
// On macOS, `import CoreGraphics` resolves to Apple's system framework.
// This module is empty on macOS (all types come from Apple).
// On Linux, it provides the missing CG/CF types.

#if !canImport(Darwin)
// -- Everything below is Linux-only --
// On Linux, the prebuilt SDK assembles this module as `CoreGraphics.framework`
// so `import CoreGraphics` resolves here instead.
//
// Foundation already provides CGFloat, CGPoint, CGSize, CGRect, CGAffineTransform
// on Linux via swift-corelibs-foundation — we just need the types that Apple
// puts in CoreGraphics but Linux Foundation doesn't have.

import Foundation

// MARK: - Core Foundation types

public typealias CFTimeInterval = Double
public typealias CFIndex = Int
public typealias CFString = NSString
public typealias CFMutableData = NSMutableData
public typealias CFAllocatorRef = OpaquePointer?
public typealias CFTypeRef = AnyObject

public struct CFRange: Sendable {
    public var location: CFIndex
    public var length: CFIndex
    public init(location: CFIndex, length: CFIndex) {
        self.location = location; self.length = length
    }
}

public func CFRangeMake(_ location: CFIndex, _ length: CFIndex) -> CFRange {
    CFRange(location: location, length: length)
}

// MARK: - ObjC runtime

/// Selector stub — Clone uses string-based dispatch on Linux.
public struct Selector: ExpressibleByStringLiteral, Hashable, Sendable {
    public let name: String
    public init(_ name: String) { self.name = name }
    public init(stringLiteral value: String) { self.name = value }
}

// MARK: - Geometry types not in Linux Foundation

/// Affine transformation matrix.
public struct CGAffineTransform: Sendable {
    public var a: CGFloat
    public var b: CGFloat
    public var c: CGFloat
    public var d: CGFloat
    public var tx: CGFloat
    public var ty: CGFloat

    public init(a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat, tx: CGFloat, ty: CGFloat) {
        self.a = a; self.b = b; self.c = c; self.d = d; self.tx = tx; self.ty = ty
    }

    public static let identity = CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
}

// MARK: - Graphics types

/// Drawing context stub — Clone renders via wgpu, not CoreGraphics paths.
open class CGContext {
    public init() {}
}

/// Color reference.
public final class CGColor: Sendable {
    public let red: CGFloat
    public let green: CGFloat
    public let blue: CGFloat
    public let alpha: CGFloat

    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    public static let black = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    public static let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    public static let clear = CGColor(red: 0, green: 0, blue: 0, alpha: 0)
}

/// Color space stub.
open class CGColorSpace {
    public init() {}
}

public func CGColorSpaceCreateDeviceRGB() -> CGColorSpace {
    CGColorSpace()
}

/// Path stub.
open class CGPath {
    public init() {}
}

/// Font stub.
open class CGFont {
    public init() {}
}

/// Image stub.
open class CGImage {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width; self.height = height
    }
}

/// Alpha info enum.
public enum CGImageAlphaInfo: UInt32 {
    case none = 0
    case premultipliedLast = 1
    case premultipliedFirst = 2
    case last = 3
    case first = 4
    case noneSkipLast = 5
    case noneSkipFirst = 6
    case alphaOnly = 7
}

#endif // !canImport(Darwin)
