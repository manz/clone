import Foundation

public struct Color: Equatable, Sendable {
    public let r: Float
    public let g: Float
    public let b: Float
    public let a: Float

    public init(r: Float, g: Float, b: Float, a: Float = 1.0) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    // System colors (macOS-inspired)
    public static let white = Color(r: 1, g: 1, b: 1)
    public static let black = Color(r: 0, g: 0, b: 0)
    public static let clear = Color(r: 0, g: 0, b: 0, a: 0)

    // Rose Pine base
    public static let base = Color(r: 0.14, g: 0.13, b: 0.19)
    public static let surface = Color(r: 0.18, g: 0.16, b: 0.24)
    public static let overlay = Color(r: 0.22, g: 0.20, b: 0.28)
    public static let text = Color(r: 0.88, g: 0.85, b: 0.91)
    public static let subtle = Color(r: 0.58, g: 0.55, b: 0.63)
    public static let muted = Color(r: 0.42, g: 0.39, b: 0.47)

    // Accent colors
    public static let systemBlue = Color(r: 0.19, g: 0.55, b: 0.91)
    public static let systemRed = Color(r: 0.92, g: 0.29, b: 0.35)
    public static let systemGreen = Color(r: 0.18, g: 0.75, b: 0.49)
    public static let systemYellow = Color(r: 0.96, g: 0.76, b: 0.29)
    public static let systemOrange = Color(r: 0.95, g: 0.55, b: 0.24)
}

public struct EdgeInsets: Equatable, Sendable {
    public let top: Float
    public let leading: Float
    public let bottom: Float
    public let trailing: Float

    public init(top: Float = 0, leading: Float = 0, bottom: Float = 0, trailing: Float = 0) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    public init(all: Float) {
        self.top = all
        self.leading = all
        self.bottom = all
        self.trailing = all
    }

    public init(horizontal: Float = 0, vertical: Float = 0) {
        self.top = vertical
        self.leading = horizontal
        self.bottom = vertical
        self.trailing = horizontal
    }
}

public enum FontWeight: Equatable, Sendable {
    case regular
    case medium
    case semibold
    case bold
}

public enum HAlignment: Equatable, Sendable {
    case leading
    case center
    case trailing
}

public enum VAlignment: Equatable, Sendable {
    case top
    case center
    case bottom
}

public typealias HorizontalAlignment = HAlignment
public typealias VerticalAlignment = VAlignment
