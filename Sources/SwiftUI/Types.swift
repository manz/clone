import Foundation
import AppKit

// MARK: - Appearance

public enum Appearance: Sendable {
    case dark
    case light
}

/// Global appearance setting. Delegates to NSAppearance (AppKit is the authority).
public final class AppearanceManager: @unchecked Sendable {
    public static let shared = AppearanceManager()

    public var current: Appearance {
        get { NSAppearance.shared.isDark ? .dark : .light }
        set { NSAppearance.shared.style = newValue == .dark ? .darkAqua : .aqua }
    }
}

// MARK: - Color

public struct Color: Equatable, Sendable {
    public let r: CGFloat
    public let g: CGFloat
    public let b: CGFloat
    public let a: CGFloat

    /// `Color(red: 0.5, green: 0.3, blue: 0.8)` — matches Apple's SwiftUI initializer.
    public init(red: CGFloat, green: CGFloat, blue: CGFloat, opacity: CGFloat = 1.0) {
        self.r = red
        self.g = green
        self.b = blue
        self.a = opacity
    }

    /// `Color(white: 0.5)` — grayscale convenience.
    public init(white: CGFloat, opacity: CGFloat = 1.0) {
        self.r = white
        self.g = white
        self.b = white
        self.a = opacity
    }

    /// Initialize from an NSColor.
    public init(nsColor: NSColor) {
        self.r = nsColor.redComponent
        self.g = nsColor.greenComponent
        self.b = nsColor.blueComponent
        self.a = nsColor.alphaComponent
    }

    /// Internal initializer used throughout Clone.
    public init(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat = 1.0) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    /// Returns this color with the given opacity. Matches Apple's SwiftUI Color.opacity().
    public func opacity(_ opacity: CGFloat) -> Color {
        Color(r: r, g: g, b: b, a: a * opacity)
    }

    /// Adaptive color — resolves to dark or light variant based on current appearance.
    public static func adaptive(dark: Color, light: Color) -> Color {
        AppearanceManager.shared.current == .dark ? dark : light
    }

    // MARK: - Fixed colors (same as Apple's SwiftUI)

    public static let white = Color(r: 1, g: 1, b: 1)
    public static let black = Color(r: 0, g: 0, b: 0)
    public static let clear = Color(r: 0, g: 0, b: 0, a: 0)

    // MARK: - Standard colors (match Apple's SwiftUI Color)

    public static let red = Color(r: 1.0, g: 0.23, b: 0.19)
    public static let orange = Color(r: 1.0, g: 0.58, b: 0.0)
    public static let yellow = Color(r: 1.0, g: 0.80, b: 0.0)
    public static let green = Color(r: 0.20, g: 0.78, b: 0.35)
    public static let mint = Color(r: 0.0, g: 0.78, b: 0.75)
    public static let teal = Color(r: 0.19, g: 0.69, b: 0.78)
    public static let cyan = Color(r: 0.20, g: 0.68, b: 0.90)
    public static let blue = Color(r: 0.04, g: 0.52, b: 1.0)
    public static let indigo = Color(r: 0.35, g: 0.34, b: 0.84)
    public static let purple = Color(r: 0.69, g: 0.32, b: 0.87)
    public static let pink = Color(r: 1.0, g: 0.18, b: 0.33)
    public static let brown = Color(r: 0.64, g: 0.52, b: 0.37)
    public static let gray = Color(r: 0.56, g: 0.56, b: 0.58)

    // MARK: - Semantic colors (match Apple's SwiftUI)

    /// Primary content color — black in light mode, white in dark mode.
    public static var primary: Color {
        adaptive(dark: .white, light: .black)
    }

    /// Secondary content color — used for less prominent text.
    public static var secondary: Color {
        adaptive(dark: Color(r: 0.92, g: 0.92, b: 0.96, a: 0.6),
                 light: Color(r: 0.24, g: 0.24, b: 0.26, a: 0.6))
    }

    /// The accent color — defaults to system blue, used for interactive elements.
    public static var accentColor: Color { .blue }

}

public struct EdgeInsets: Equatable, Sendable {
    public let top: CGFloat
    public let leading: CGFloat
    public let bottom: CGFloat
    public let trailing: CGFloat

    public init(top: CGFloat = 0, leading: CGFloat = 0, bottom: CGFloat = 0, trailing: CGFloat = 0) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    public init(all: CGFloat) {
        self.top = all
        self.leading = all
        self.bottom = all
        self.trailing = all
    }

    public init(horizontal: CGFloat = 0, vertical: CGFloat = 0) {
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
