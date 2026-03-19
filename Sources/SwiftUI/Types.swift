import Foundation

// MARK: - Appearance

public enum Appearance: Sendable {
    case dark
    case light
}

/// Global appearance setting. Apps and the compositor read this to resolve semantic colors.
public final class AppearanceManager: @unchecked Sendable {
    public static let shared = AppearanceManager()
    public var current: Appearance = .light
}

// MARK: - Color

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

    /// Adaptive color — resolves to dark or light variant based on current appearance.
    public static func adaptive(dark: Color, light: Color) -> Color {
        AppearanceManager.shared.current == .dark ? dark : light
    }

    // Primitives
    public static let white = Color(r: 1, g: 1, b: 1)
    public static let black = Color(r: 0, g: 0, b: 0)
    public static let clear = Color(r: 0, g: 0, b: 0, a: 0)

    // MARK: - Semantic colors (adaptive)

    // Backgrounds
    public static var base: Color {
        adaptive(dark: Color(r: 0.11, g: 0.11, b: 0.12),
                 light: Color(r: 0.93, g: 0.93, b: 0.94))
    }
    public static var surface: Color {
        adaptive(dark: Color(r: 0.16, g: 0.16, b: 0.17),
                 light: Color(r: 1.0, g: 1.0, b: 1.0))
    }
    public static var overlay: Color {
        adaptive(dark: Color(r: 0.22, g: 0.22, b: 0.23),
                 light: Color(r: 0.85, g: 0.85, b: 0.86))
    }

    // Text
    public static var text: Color {
        adaptive(dark: Color(r: 1.0, g: 1.0, b: 1.0),
                 light: Color(r: 0.0, g: 0.0, b: 0.0))
    }
    public static var subtle: Color {
        adaptive(dark: Color(r: 0.56, g: 0.56, b: 0.58),
                 light: Color(r: 0.44, g: 0.44, b: 0.46))
    }
    public static var muted: Color {
        adaptive(dark: Color(r: 0.36, g: 0.36, b: 0.38),
                 light: Color(r: 0.64, g: 0.64, b: 0.66))
    }

    // Window chrome
    public static var titleBar: Color {
        adaptive(dark: Color(r: 0.20, g: 0.20, b: 0.21),
                 light: Color(r: 0.90, g: 0.90, b: 0.91))
    }
    public static var titleBarUnfocused: Color {
        adaptive(dark: Color(r: 0.15, g: 0.15, b: 0.16),
                 light: Color(r: 0.96, g: 0.96, b: 0.96))
    }
    public static var windowBackground: Color {
        adaptive(dark: Color(r: 0.14, g: 0.14, b: 0.15),
                 light: Color(r: 0.96, g: 0.96, b: 0.97))
    }
    public static var sidebarBackground: Color {
        adaptive(dark: Color(r: 0.12, g: 0.12, b: 0.13),
                 light: Color(r: 0.96, g: 0.96, b: 0.97))
    }
    public static var separator: Color {
        adaptive(dark: Color(r: 0.30, g: 0.30, b: 0.31),
                 light: Color(r: 0.82, g: 0.82, b: 0.83))
    }
    public static var selection: Color {
        adaptive(dark: Color(r: 0.04, g: 0.52, b: 1.0, a: 0.3),
                 light: Color(r: 0.04, g: 0.52, b: 1.0, a: 0.2))
    }
    public static var highlight: Color {
        adaptive(dark: Color(r: 1.0, g: 1.0, b: 1.0, a: 0.06),
                 light: Color(r: 0.0, g: 0.0, b: 0.0, a: 0.04))
    }

    // System chrome
    public static var dockBackground: Color {
        adaptive(dark: Color(r: 0.2, g: 0.2, b: 0.2, a: 0.6),
                 light: Color(r: 0.95, g: 0.95, b: 0.95, a: 0.7))
    }
    public static var menuBarBackground: Color {
        adaptive(dark: Color(r: 0.1, g: 0.1, b: 0.1, a: 0.5),
                 light: Color(r: 0.96, g: 0.96, b: 0.96, a: 0.8))
    }
    public static var popoverBackground: Color {
        adaptive(dark: Color(r: 0.15, g: 0.15, b: 0.16, a: 0.95),
                 light: Color(r: 0.98, g: 0.98, b: 0.98, a: 0.95))
    }

    // macOS system accent colors (same in both modes)
    public static let systemBlue = Color(r: 0.04, g: 0.52, b: 1.0)
    public static let systemRed = Color(r: 1.0, g: 0.27, b: 0.23)
    public static let systemGreen = Color(r: 0.19, g: 0.82, b: 0.35)
    public static let systemYellow = Color(r: 1.0, g: 0.84, b: 0.04)
    public static let systemOrange = Color(r: 1.0, g: 0.62, b: 0.04)
    public static let systemPurple = Color(r: 0.69, g: 0.32, b: 0.87)
    public static let systemTeal = Color(r: 0.35, g: 0.78, b: 0.98)
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
