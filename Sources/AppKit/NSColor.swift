import Foundation

/// AppKit NSColor shim for Linux. Provides the same semantic color API as macOS.
/// On real macOS, apps import AppKit and get the real NSColor. On Clone/Linux,
/// they import this module and get adaptive colors matching macOS appearance.
///
/// Reference: https://developer.apple.com/documentation/appkit/nscolor
public final class NSColor: @unchecked Sendable {

    public let redComponent: CGFloat
    public let greenComponent: CGFloat
    public let blueComponent: CGFloat
    public let alphaComponent: CGFloat

    private init(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) {
        self.redComponent = r; self.greenComponent = g
        self.blueComponent = b; self.alphaComponent = a
    }

    private static func adaptive(dark: NSColor, light: NSColor) -> NSColor {
        NSAppearance.shared.isDark ? dark : light
    }

    // MARK: - Label Colors

    public static var labelColor: NSColor {
        adaptive(dark: NSColor(1.0, 1.0, 1.0),
                 light: NSColor(0.0, 0.0, 0.0))
    }

    public static var secondaryLabelColor: NSColor {
        adaptive(dark: NSColor(1.0, 1.0, 1.0, 0.55),
                 light: NSColor(0.0, 0.0, 0.0, 0.55))
    }

    public static var tertiaryLabelColor: NSColor {
        adaptive(dark: NSColor(1.0, 1.0, 1.0, 0.25),
                 light: NSColor(0.0, 0.0, 0.0, 0.25))
    }

    public static var quaternaryLabelColor: NSColor {
        adaptive(dark: NSColor(1.0, 1.0, 1.0, 0.10),
                 light: NSColor(0.0, 0.0, 0.0, 0.10))
    }

    // MARK: - Text Colors

    public static var textColor: NSColor {
        adaptive(dark: NSColor(1.0, 1.0, 1.0),
                 light: NSColor(0.0, 0.0, 0.0))
    }

    public static var placeholderTextColor: NSColor {
        adaptive(dark: NSColor(1.0, 1.0, 1.0, 0.25),
                 light: NSColor(0.0, 0.0, 0.0, 0.25))
    }

    public static var selectedTextColor: NSColor {
        adaptive(dark: NSColor(1.0, 1.0, 1.0),
                 light: NSColor(0.0, 0.0, 0.0))
    }

    public static var textBackgroundColor: NSColor {
        adaptive(dark: NSColor(0.12, 0.12, 0.13),
                 light: NSColor(1.0, 1.0, 1.0))
    }

    public static var selectedTextBackgroundColor: NSColor {
        adaptive(dark: NSColor(0.04, 0.52, 1.0, 0.5),
                 light: NSColor(0.04, 0.52, 1.0, 0.3))
    }

    public static var unemphasizedSelectedTextBackgroundColor: NSColor {
        adaptive(dark: NSColor(0.27, 0.27, 0.28),
                 light: NSColor(0.84, 0.84, 0.85))
    }

    public static var unemphasizedSelectedTextColor: NSColor {
        adaptive(dark: NSColor(1.0, 1.0, 1.0),
                 light: NSColor(0.0, 0.0, 0.0))
    }

    // MARK: - Content Colors

    public static var linkColor: NSColor {
        adaptive(dark: NSColor(0.25, 0.61, 1.0),
                 light: NSColor(0.04, 0.52, 1.0))
    }

    public static var separatorColor: NSColor {
        adaptive(dark: NSColor(1.0, 1.0, 1.0, 0.10),
                 light: NSColor(0.0, 0.0, 0.0, 0.10))
    }

    public static var selectedContentBackgroundColor: NSColor {
        adaptive(dark: NSColor(0.04, 0.52, 1.0),
                 light: NSColor(0.04, 0.52, 1.0))
    }

    public static var unemphasizedSelectedContentBackgroundColor: NSColor {
        adaptive(dark: NSColor(0.27, 0.27, 0.28),
                 light: NSColor(0.84, 0.84, 0.85))
    }

    // MARK: - Menu Colors

    public static var selectedMenuItemTextColor: NSColor {
        NSColor(1.0, 1.0, 1.0)
    }

    // MARK: - Table / List Colors

    public static var gridColor: NSColor {
        adaptive(dark: NSColor(0.22, 0.22, 0.23),
                 light: NSColor(0.88, 0.88, 0.88))
    }

    public static var headerTextColor: NSColor {
        adaptive(dark: NSColor(1.0, 1.0, 1.0),
                 light: NSColor(0.0, 0.0, 0.0))
    }

    public static var alternatingContentBackgroundColors: [NSColor] {
        if NSAppearance.shared.isDark {
            return [NSColor(0.14, 0.14, 0.15), NSColor(0.16, 0.16, 0.17)]
        } else {
            return [NSColor(1.0, 1.0, 1.0), NSColor(0.95, 0.95, 0.96)]
        }
    }

    // MARK: - Control Colors

    public static var controlAccentColor: NSColor {
        NSColor(0.04, 0.52, 1.0)
    }

    public static var controlColor: NSColor {
        adaptive(dark: NSColor(1.0, 1.0, 1.0, 0.25),
                 light: NSColor(1.0, 1.0, 1.0))
    }

    public static var controlBackgroundColor: NSColor {
        adaptive(dark: NSColor(0.12, 0.12, 0.13),
                 light: NSColor(1.0, 1.0, 1.0))
    }

    public static var controlTextColor: NSColor {
        adaptive(dark: NSColor(1.0, 1.0, 1.0, 0.85),
                 light: NSColor(0.0, 0.0, 0.0, 0.85))
    }

    public static var disabledControlTextColor: NSColor {
        adaptive(dark: NSColor(1.0, 1.0, 1.0, 0.25),
                 light: NSColor(0.0, 0.0, 0.0, 0.25))
    }

    public static var selectedControlColor: NSColor {
        adaptive(dark: NSColor(0.04, 0.52, 1.0, 0.5),
                 light: NSColor(0.04, 0.52, 1.0, 0.3))
    }

    public static var selectedControlTextColor: NSColor {
        adaptive(dark: NSColor(1.0, 1.0, 1.0),
                 light: NSColor(0.0, 0.0, 0.0))
    }

    public static var alternateSelectedControlTextColor: NSColor {
        NSColor(1.0, 1.0, 1.0)
    }

    // MARK: - Window Colors

    public static var windowBackgroundColor: NSColor {
        adaptive(dark: NSColor(0.14, 0.14, 0.15),
                 light: NSColor(0.93, 0.93, 0.94))
    }

    public static var windowFrameTextColor: NSColor {
        adaptive(dark: NSColor(1.0, 1.0, 1.0, 0.85),
                 light: NSColor(0.0, 0.0, 0.0, 0.85))
    }

    public static var underPageBackgroundColor: NSColor {
        adaptive(dark: NSColor(0.08, 0.08, 0.09),
                 light: NSColor(0.59, 0.59, 0.59))
    }

    // MARK: - Highlight & Shadow

    public static var findHighlightColor: NSColor {
        NSColor(1.0, 1.0, 0.0)
    }

    public static var highlightColor: NSColor {
        adaptive(dark: NSColor(0.71, 0.71, 0.71),
                 light: NSColor(1.0, 1.0, 1.0))
    }

    public static var shadowColor: NSColor {
        NSColor(0.0, 0.0, 0.0)
    }

    // MARK: - Sidebar (macOS 11+)

    public static var sidebarBackgroundColor: NSColor {
        adaptive(dark: NSColor(0.12, 0.12, 0.13),
                 light: NSColor(0.96, 0.96, 0.97))
    }

    // MARK: - Standard System Colors

    public static let systemRed = NSColor(1.0, 0.23, 0.19)
    public static let systemOrange = NSColor(1.0, 0.58, 0.0)
    public static let systemYellow = NSColor(1.0, 0.80, 0.0)
    public static let systemGreen = NSColor(0.20, 0.78, 0.35)
    public static let systemMint = NSColor(0.0, 0.78, 0.75)
    public static let systemTeal = NSColor(0.19, 0.69, 0.78)
    public static let systemCyan = NSColor(0.20, 0.68, 0.90)
    public static let systemBlue = NSColor(0.04, 0.52, 1.0)
    public static let systemIndigo = NSColor(0.35, 0.34, 0.84)
    public static let systemPurple = NSColor(0.69, 0.32, 0.87)
    public static let systemPink = NSColor(1.0, 0.18, 0.33)
    public static let systemBrown = NSColor(0.64, 0.52, 0.37)
    public static let systemGray = NSColor(0.56, 0.56, 0.58)

    public static let white = NSColor(1.0, 1.0, 1.0)
    public static let black = NSColor(0.0, 0.0, 0.0)
    public static let clear = NSColor(0.0, 0.0, 0.0, 0.0)
}
