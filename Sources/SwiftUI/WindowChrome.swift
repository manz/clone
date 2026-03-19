import Foundation
import AppKit

/// Internal colors for the Clone window compositor and system chrome.
/// Delegates to NSColor semantic colors where a direct mapping exists.
extension WindowChrome {

    // MARK: - Window

    public static var background: Color { Color(nsColor: .windowBackgroundColor) }
    public static var backgroundUnfocused: Color { Color(nsColor: .windowBackgroundColor) }

    public static var titleBar: Color {
        Color.adaptive(dark: Color(r: 0.20, g: 0.20, b: 0.21),
                        light: Color(r: 0.90, g: 0.90, b: 0.91))
    }

    public static var titleBarUnfocused: Color {
        Color.adaptive(dark: Color(r: 0.15, g: 0.15, b: 0.16),
                        light: Color(r: 0.96, g: 0.96, b: 0.96))
    }

    public static var sidebar: Color { Color(nsColor: .sidebarBackgroundColor) }
    public static var separator: Color { Color(nsColor: .separatorColor) }
    public static var selection: Color { Color(nsColor: .selectedControlColor) }

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

    public static var base: Color { Color(nsColor: .windowBackgroundColor) }
    public static var surface: Color { Color(nsColor: .controlBackgroundColor) }
    public static var overlay: Color { Color(nsColor: .gridColor) }
}
