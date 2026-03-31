// CoreGraphics — Clone's CoreGraphics module.
//
// SPM target name is `CoreGraphics`, shadowing Apple's system framework.
// On macOS, Apple's CoreGraphics is useless at runtime (Clone uses wgpu).
// Our stubs provide just enough API surface for SDK code to compile.
//
// Foundation provides CGFloat, CGPoint, CGSize, CGRect on both platforms.
// CF types and Selector only exist on Linux (macOS gets them from system libs).
// Graphics stubs (CGColor, CGContext, CGPath, etc.) are provided on both.

import Foundation

// MARK: - Core Foundation types (Linux only — macOS gets these from CoreFoundation)

#if !canImport(Darwin)

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

#endif

// MARK: - Graphics types (both platforms — Clone doesn't use Apple's CG drawing)

/// Drawing context stub — Clone renders via wgpu, not CoreGraphics paths.
open class CGContext: @unchecked Sendable {
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
open class CGColorSpace: @unchecked Sendable {
    public init() {}
}

public func CGColorSpaceCreateDeviceRGB() -> CGColorSpace {
    CGColorSpace()
}

/// Path stub.
open class CGPath: @unchecked Sendable {
    public init() {}
}

/// Font stub.
open class CGFont: @unchecked Sendable {
    public init() {}
}

/// Image stub.
open class CGImage: @unchecked Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width; self.height = height
    }
}

/// Alpha info enum.
public enum CGImageAlphaInfo: UInt32, Sendable {
    case none = 0
    case premultipliedLast = 1
    case premultipliedFirst = 2
    case last = 3
    case first = 4
    case noneSkipLast = 5
    case noneSkipFirst = 6
    case alphaOnly = 7
}

// MARK: - CGRect extensions (macOS only — Linux Foundation has these built in)
//
// Apple's CoreGraphics adds computed properties and methods to CGRect.
// Since we shadow that module, we need to provide them ourselves on macOS.

// MARK: - CGRect / CGPoint convenience initialisers & helpers (macOS only)
//
// On macOS, Foundation provides the bare struct (origin + size) but the
// convenience initialisers and computed properties live in Apple's
// CoreGraphics overlay — which we shadow. Re-provide them here.
// Linux's swift-corelibs-foundation already has these built in.

#if canImport(Darwin)

extension CGRect {
    @inlinable
    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.init(origin: CGPoint(x: x, y: y), size: CGSize(width: width, height: height))
    }

    @inlinable
    public init(x: Int, y: Int, width: Int, height: Int) {
        self.init(origin: CGPoint(x: CGFloat(x), y: CGFloat(y)),
                  size: CGSize(width: CGFloat(width), height: CGFloat(height)))
    }

    @inlinable
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(origin: CGPoint(x: CGFloat(x), y: CGFloat(y)),
                  size: CGSize(width: CGFloat(width), height: CGFloat(height)))
    }

    public var width: CGFloat { size.width }
    public var height: CGFloat { size.height }
    public var minX: CGFloat { origin.x }
    public var minY: CGFloat { origin.y }
    public var maxX: CGFloat { origin.x + size.width }
    public var maxY: CGFloat { origin.y + size.height }
    public var midX: CGFloat { origin.x + size.width / 2 }
    public var midY: CGFloat { origin.y + size.height / 2 }

    public func contains(_ point: CGPoint) -> Bool {
        point.x >= minX && point.x < maxX && point.y >= minY && point.y < maxY
    }

    public func contains(_ rect: CGRect) -> Bool {
        rect.minX >= minX && rect.maxX <= maxX && rect.minY >= minY && rect.maxY <= maxY
    }

    public func intersects(_ rect: CGRect) -> Bool {
        minX < rect.maxX && maxX > rect.minX && minY < rect.maxY && maxY > rect.minY
    }

    public func intersection(_ other: CGRect) -> CGRect {
        let x = Swift.max(minX, other.minX)
        let y = Swift.max(minY, other.minY)
        let w = Swift.min(maxX, other.maxX) - x
        let h = Swift.min(maxY, other.maxY) - y
        guard w > 0, h > 0 else { return .null }
        return CGRect(origin: CGPoint(x: x, y: y), size: CGSize(width: w, height: h))
    }

    public func union(_ other: CGRect) -> CGRect {
        let x = Swift.min(minX, other.minX)
        let y = Swift.min(minY, other.minY)
        let w = Swift.max(maxX, other.maxX) - x
        let h = Swift.max(maxY, other.maxY) - y
        return CGRect(origin: CGPoint(x: x, y: y), size: CGSize(width: w, height: h))
    }

    public func insetBy(dx: CGFloat, dy: CGFloat) -> CGRect {
        CGRect(origin: CGPoint(x: origin.x + dx, y: origin.y + dy),
               size: CGSize(width: size.width - 2 * dx, height: size.height - 2 * dy))
    }

    public func offsetBy(dx: CGFloat, dy: CGFloat) -> CGRect {
        CGRect(origin: CGPoint(x: origin.x + dx, y: origin.y + dy), size: size)
    }

    public static let null = CGRect(origin: CGPoint(x: CGFloat.infinity, y: CGFloat.infinity),
                                    size: CGSize(width: 0, height: 0))

    public var isNull: Bool { origin.x.isInfinite || origin.y.isInfinite }
    public var isEmpty: Bool { isNull || size.width == 0 || size.height == 0 }

    public var integral: CGRect {
        let x = origin.x.rounded(.down)
        let y = origin.y.rounded(.down)
        let w = (origin.x + size.width).rounded(.up) - x
        let h = (origin.y + size.height).rounded(.up) - y
        return CGRect(origin: CGPoint(x: x, y: y), size: CGSize(width: w, height: h))
    }

    public var standardized: CGRect {
        var r = self
        if r.size.width < 0 { r.origin.x += r.size.width; r.size.width = -r.size.width }
        if r.size.height < 0 { r.origin.y += r.size.height; r.size.height = -r.size.height }
        return r
    }
}

extension CGPoint: @retroactive Equatable {
    public static func == (lhs: CGPoint, rhs: CGPoint) -> Bool {
        lhs.x == rhs.x && lhs.y == rhs.y
    }

    public static let zero = CGPoint()

    @inlinable
    public init(x: Int, y: Int) {
        self.init(x: CGFloat(x), y: CGFloat(y))
    }

    @inlinable
    public init(x: Double, y: Double) {
        self.init(x: CGFloat(x), y: CGFloat(y))
    }
}

extension CGSize {
    public static let zero = CGSize()

    @inlinable
    public init(width: Int, height: Int) {
        self.init(width: CGFloat(width), height: CGFloat(height))
    }

    @inlinable
    public init(width: Double, height: Double) {
        self.init(width: CGFloat(width), height: CGFloat(height))
    }
}

extension CGRect {
    public static let zero = CGRect()
}

extension CGFloat {
    public static let zero: CGFloat = 0
}

#endif
