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

    /// Initialize from an NSColor (labeled).
    public init(nsColor: NSColor) {
        self.r = nsColor.redComponent
        self.g = nsColor.greenComponent
        self.b = nsColor.blueComponent
        self.a = nsColor.alphaComponent
    }

    /// Initialize from an NSColor (unlabeled). Matches `Color(NSColor.controlBackgroundColor)`.
    public init(_ nsColor: NSColor) {
        self.r = nsColor.redComponent
        self.g = nsColor.greenComponent
        self.b = nsColor.blueComponent
        self.a = nsColor.alphaComponent
    }

    /// `Color(hue: 0.5, saturation: 0.8, brightness: 0.9)` — HSB color.
    public init(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, opacity: CGFloat = 1.0) {
        // HSB to RGB conversion
        let c = brightness * saturation
        let x = c * (1 - abs((hue * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = brightness - c
        let (r1, g1, b1): (CGFloat, CGFloat, CGFloat)
        let h = hue * 6
        if h < 1 { (r1, g1, b1) = (c, x, 0) }
        else if h < 2 { (r1, g1, b1) = (x, c, 0) }
        else if h < 3 { (r1, g1, b1) = (0, c, x) }
        else if h < 4 { (r1, g1, b1) = (0, x, c) }
        else if h < 5 { (r1, g1, b1) = (x, 0, c) }
        else { (r1, g1, b1) = (c, 0, x) }
        self.r = r1 + m; self.g = g1 + m; self.b = b1 + m; self.a = opacity
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

    // MARK: - Material approximations

    public static var ultraThinMaterial: Color { Color(white: 0.5, opacity: 0.1) }
    public static var thinMaterial: Color { Color(white: 0.5, opacity: 0.2) }
    public static var regularMaterial: Color { Color(white: 0.5, opacity: 0.3) }
    public static var thickMaterial: Color { Color(white: 0.5, opacity: 0.4) }
    public static var ultraThickMaterial: Color { Color(white: 0.5, opacity: 0.5) }
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

/// Re-exported from CoreText (cosmic-text). Same enum used by the Rust renderer.
public typealias FontWeight = CTFontWeight

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

// MARK: - Alignment (combined horizontal + vertical)

public struct Alignment: Equatable, Sendable {
    public let horizontal: HAlignment
    public let vertical: VAlignment

    public init(horizontal: HAlignment, vertical: VAlignment) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    public static let center = Alignment(horizontal: .center, vertical: .center)
    public static let leading = Alignment(horizontal: .leading, vertical: .center)
    public static let trailing = Alignment(horizontal: .trailing, vertical: .center)
    public static let top = Alignment(horizontal: .center, vertical: .top)
    public static let bottom = Alignment(horizontal: .center, vertical: .bottom)
    public static let topLeading = Alignment(horizontal: .leading, vertical: .top)
    public static let topTrailing = Alignment(horizontal: .trailing, vertical: .top)
    public static let bottomLeading = Alignment(horizontal: .leading, vertical: .bottom)
    public static let bottomTrailing = Alignment(horizontal: .trailing, vertical: .bottom)
}

// MARK: - KeyEquivalent

public struct KeyEquivalent: ExpressibleByStringLiteral, Equatable, Sendable {
    public let character: Character
    public init(_ character: Character) { self.character = character }
    public init(stringLiteral value: String) { self.character = value.first ?? " " }

    public static let `return` = KeyEquivalent("\r")
    public static let escape = KeyEquivalent("\u{1B}")
    public static let cancelAction = KeyEquivalent("\u{1B}")
    public static let delete = KeyEquivalent("\u{7F}")
    public static let tab = KeyEquivalent("\t")
    public static let space = KeyEquivalent(" ")
    public static let defaultAction = KeyEquivalent("\r")
    public static let upArrow = KeyEquivalent("\u{F700}")
    public static let downArrow = KeyEquivalent("\u{F701}")
    public static let leftArrow = KeyEquivalent("\u{F702}")
    public static let rightArrow = KeyEquivalent("\u{F703}")
}

// MARK: - EventModifiers

public struct EventModifiers: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let capsLock = EventModifiers(rawValue: 1 << 0)
    public static let shift = EventModifiers(rawValue: 1 << 1)
    public static let control = EventModifiers(rawValue: 1 << 2)
    public static let option = EventModifiers(rawValue: 1 << 3)
    public static let command = EventModifiers(rawValue: 1 << 4)
    public static let numericPad = EventModifiers(rawValue: 1 << 5)
    public static let all = EventModifiers(rawValue: ~0)
}

// MARK: - ContentMode

public enum ContentMode: Sendable { case fit, fill }

// MARK: - PresentationDetent

public struct PresentationDetent: Hashable, Sendable {
    let id: Int
    private init(id: Int) { self.id = id }
    public init() { self.id = 0 }
    public static let medium = PresentationDetent(id: 1)
    public static let large = PresentationDetent(id: 2)
    public static func fraction(_ fraction: CGFloat) -> PresentationDetent { PresentationDetent(id: 3) }
    public static func height(_ height: CGFloat) -> PresentationDetent { PresentationDetent(id: 4) }
}

// MARK: - TextAlignment

public enum TextAlignment: Sendable { case leading, center, trailing }

// MARK: - KeyPress

public struct KeyPress {
    public enum Result {
        case handled
        case ignored
    }
    public var key: KeyEquivalent { KeyEquivalent("") }
}

// MARK: - NavigationBarItem

public enum NavigationBarItem {
    public enum TitleDisplayMode {
        case automatic, inline, large
    }
}

// MARK: - Visibility

public enum Visibility: Sendable {
    case automatic, visible, hidden
}

// MARK: - ContentMarginPlacement

public struct ContentMarginPlacement: Sendable {
    public static let automatic = ContentMarginPlacement()
    public static let scrollContent = ContentMarginPlacement()
    public static let scrollIndicators = ContentMarginPlacement()
}

// MARK: - ScrollIndicatorVisibility

public struct ScrollIndicatorVisibility: Sendable {
    public static let automatic = ScrollIndicatorVisibility()
    public static let visible = ScrollIndicatorVisibility()
    public static let hidden = ScrollIndicatorVisibility()
    public static let never = ScrollIndicatorVisibility()
}

// MARK: - SensoryFeedback

public enum SensoryFeedback: Sendable {
    case success, warning, error, selection, impact, alignment, levelChange, increase, decrease
}

// MARK: - Prominence

public enum Prominence: Sendable {
    case standard, increased
}

// MARK: - ColorScheme

public enum ColorScheme: Sendable {
    case light, dark
}

// MARK: - TextSelectability

public enum TextSelectability: Sendable {
    public static let enabled = TextSelectability.on
    public static let disabled = TextSelectability.off
    case on, off
}

// MARK: - ControlSize

public enum ControlSize: Sendable { case mini, small, regular, large, extraLarge }

// MARK: - Axis.Set

extension Axis {
    public struct Set: OptionSet, Sendable {
        public let rawValue: UInt8
        public init(rawValue: UInt8) { self.rawValue = rawValue }
        public static let horizontal = Set(rawValue: 1 << 0)
        public static let vertical = Set(rawValue: 1 << 1)
    }
}

// MARK: - AccessibilityTraits

public struct AccessibilityTraits: OptionSet, Sendable {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }
    public static let isButton = AccessibilityTraits(rawValue: 1 << 0)
    public static let isHeader = AccessibilityTraits(rawValue: 1 << 1)
    public static let isSelected = AccessibilityTraits(rawValue: 1 << 2)
    public static let isLink = AccessibilityTraits(rawValue: 1 << 3)
    public static let isImage = AccessibilityTraits(rawValue: 1 << 4)
    public static let isStaticText = AccessibilityTraits(rawValue: 1 << 5)
    public static let playsSound = AccessibilityTraits(rawValue: 1 << 6)
    public static let isKeyboardKey = AccessibilityTraits(rawValue: 1 << 7)
    public static let isSummaryElement = AccessibilityTraits(rawValue: 1 << 8)
    public static let isSearchField = AccessibilityTraits(rawValue: 1 << 9)
    public static let startsMediaSession = AccessibilityTraits(rawValue: 1 << 10)
    public static let updatesFrequently = AccessibilityTraits(rawValue: 1 << 11)
    public static let allowsDirectInteraction = AccessibilityTraits(rawValue: 1 << 12)
    public static let isToggle = AccessibilityTraits(rawValue: 1 << 13)
    public static let isModal = AccessibilityTraits(rawValue: 1 << 14)
}

// MARK: - NavigationSplitViewStyle

public protocol NavigationSplitViewStyleProtocol {}

public struct BalancedNavigationSplitViewStyle: NavigationSplitViewStyleProtocol {
    public init() {}
}

public struct ProminentDetailNavigationSplitViewStyle: NavigationSplitViewStyleProtocol {
    public init() {}
}

public struct AutomaticNavigationSplitViewStyle: NavigationSplitViewStyleProtocol {
    public init() {}
}

extension NavigationSplitViewStyleProtocol where Self == BalancedNavigationSplitViewStyle {
    public static var balanced: BalancedNavigationSplitViewStyle { .init() }
}
extension NavigationSplitViewStyleProtocol where Self == ProminentDetailNavigationSplitViewStyle {
    public static var prominentDetail: ProminentDetailNavigationSplitViewStyle { .init() }
}
extension NavigationSplitViewStyleProtocol where Self == AutomaticNavigationSplitViewStyle {
    public static var automatic: AutomaticNavigationSplitViewStyle { .init() }
}

// MARK: - SymbolRenderingMode

public enum SymbolRenderingMode: Sendable {
    case monochrome, multicolor, hierarchical, palette
}

// MARK: - SubmitLabel

public struct SubmitLabel: Sendable {
    public static let done = SubmitLabel()
    public static let go = SubmitLabel()
    public static let send = SubmitLabel()
    public static let join = SubmitLabel()
    public static let route = SubmitLabel()
    public static let search = SubmitLabel()
    public static let `return` = SubmitLabel()
    public static let next = SubmitLabel()
    public static let `continue` = SubmitLabel()
}

// MARK: - GlassEffectStyle

public struct GlassEffectStyle: Sendable {
    public static let regular = GlassEffectStyle()
    public static let thin = GlassEffectStyle()
    public static let thick = GlassEffectStyle()

    public func interactive() -> GlassEffectStyle { self }
}

// MARK: - SubmitTriggers

public struct SubmitTriggers: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let text = SubmitTriggers(rawValue: 1 << 0)
    public static let search = SubmitTriggers(rawValue: 1 << 1)
}

// MARK: - SymbolEffect

public struct SymbolEffect: Sendable {
    public static let pulse = SymbolEffect()
    public static let bounce = SymbolEffect()
    public static let variableColor = SymbolEffect()
    public static let scale = SymbolEffect()
    public static let appear = SymbolEffect()
    public static let disappear = SymbolEffect()
    public static let replace = SymbolEffect()
    public static let rotate = SymbolEffect()
    public var down: SymbolEffect { self }
    public var up: SymbolEffect { self }
    public var byLayer: SymbolEffect { self }
}

// MARK: - ShapeStyle

public protocol ShapeStyle {}
extension Color: ShapeStyle {}

/// Type-erased ShapeStyle.
public struct AnyShapeStyle: ShapeStyle {
    public init<S: ShapeStyle>(_ style: S) {}
}

// MARK: - Material

public struct Material: ShapeStyle, Sendable {
    public static let ultraThinMaterial = Material()
    public static let thinMaterial = Material()
    public static let regularMaterial = Material()
    public static let thickMaterial = Material()
    public static let ultraThickMaterial = Material()
}

/// Allow `.thinMaterial` etc. in ShapeStyle context.
extension ShapeStyle where Self == Material {
    public static var thinMaterial: Material { .thinMaterial }
    public static var ultraThinMaterial: Material { .ultraThinMaterial }
    public static var regularMaterial: Material { .regularMaterial }
    public static var thickMaterial: Material { .thickMaterial }
    public static var ultraThickMaterial: Material { .ultraThickMaterial }
}

// MARK: - ToolbarPlacement

public struct ToolbarPlacement: Sendable {
    public static let automatic = ToolbarPlacement()
    public static let windowToolbar = ToolbarPlacement()
    public static let navigationBar = ToolbarPlacement()
    public static let tabBar = ToolbarPlacement()
    public static let bottomBar = ToolbarPlacement()
}
