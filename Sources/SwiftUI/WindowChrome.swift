import Foundation

/// Internal colors for the Clone window compositor and system chrome.
/// Apps should use standard Color values (.primary, .secondary, .gray, etc.)
extension WindowChrome {

    // MARK: - Window

    public static var background: Color {
        Color.adaptive(dark: Color(r: 0.14, g: 0.14, b: 0.15),
                        light: Color(r: 0.96, g: 0.96, b: 0.97))
    }

    public static var backgroundUnfocused: Color {
        Color.adaptive(dark: Color(r: 0.14, g: 0.14, b: 0.15),
                        light: Color(r: 0.96, g: 0.96, b: 0.97))
    }

    public static var titleBar: Color {
        Color.adaptive(dark: Color(r: 0.20, g: 0.20, b: 0.21),
                        light: Color(r: 0.90, g: 0.90, b: 0.91))
    }

    public static var titleBarUnfocused: Color {
        Color.adaptive(dark: Color(r: 0.15, g: 0.15, b: 0.16),
                        light: Color(r: 0.96, g: 0.96, b: 0.96))
    }

    public static var sidebar: Color {
        Color.adaptive(dark: Color(r: 0.12, g: 0.12, b: 0.13),
                        light: Color(r: 0.96, g: 0.96, b: 0.97))
    }

    public static var separator: Color {
        Color.adaptive(dark: Color(r: 0.30, g: 0.30, b: 0.31),
                        light: Color(r: 0.82, g: 0.82, b: 0.83))
    }

    public static var selection: Color {
        Color.adaptive(dark: Color(r: 0.04, g: 0.52, b: 1.0, a: 0.3),
                        light: Color(r: 0.04, g: 0.52, b: 1.0, a: 0.2))
    }

    public static var highlight: Color {
        Color.adaptive(dark: Color(r: 1.0, g: 1.0, b: 1.0, a: 0.06),
                        light: Color(r: 0.0, g: 0.0, b: 0.0, a: 0.04))
    }

    // MARK: - System chrome

    public static var dock: Color {
        Color.adaptive(dark: Color(r: 0.2, g: 0.2, b: 0.2, a: 0.6),
                        light: Color(r: 0.95, g: 0.95, b: 0.95, a: 0.7))
    }

    public static var menuBar: Color {
        Color.adaptive(dark: Color(r: 0.1, g: 0.1, b: 0.1, a: 0.5),
                        light: Color(r: 0.96, g: 0.96, b: 0.96, a: 0.8))
    }

    public static var popover: Color {
        Color.adaptive(dark: Color(r: 0.15, g: 0.15, b: 0.16, a: 0.95),
                        light: Color(r: 0.98, g: 0.98, b: 0.98, a: 0.95))
    }

    // MARK: - Background tiers

    public static var base: Color {
        Color.adaptive(dark: Color(r: 0.11, g: 0.11, b: 0.12),
                        light: Color(r: 0.93, g: 0.93, b: 0.94))
    }

    public static var surface: Color {
        Color.adaptive(dark: Color(r: 0.16, g: 0.16, b: 0.17),
                        light: Color(r: 1.0, g: 1.0, b: 1.0))
    }

    public static var overlay: Color {
        Color.adaptive(dark: Color(r: 0.22, g: 0.22, b: 0.23),
                        light: Color(r: 0.85, g: 0.85, b: 0.86))
    }
}
