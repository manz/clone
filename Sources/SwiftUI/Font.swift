import Foundation

/// A font that you apply to text in a view.
/// Matches Apple's SwiftUI Font API.
public struct Font: Equatable, Sendable {
    public let size: CGFloat
    public let weight: Weight

    /// Font weight — matches Apple's Font.Weight.
    public struct Weight: Equatable, Sendable {
        public let value: CGFloat

        public init(_ value: CGFloat) { self.value = value }

        public static let ultraLight = Weight(-0.8)
        public static let thin = Weight(-0.6)
        public static let light = Weight(-0.4)
        public static let regular = Weight(0)
        public static let medium = Weight(0.23)
        public static let semibold = Weight(0.3)
        public static let bold = Weight(0.4)
        public static let heavy = Weight(0.56)
        public static let black = Weight(0.62)
    }

    /// Font design — matches Apple's Font.Design.
    public enum Design: Sendable {
        case `default`
        case serif
        case rounded
        case monospaced
    }

    internal init(size: CGFloat, weight: Weight) {
        self.size = size
        self.weight = weight
    }

    // MARK: - System font

    /// `Font.system(size: 14, weight: .semibold)`
    public static func system(size: CGFloat, weight: Weight = .regular, design: Design = .default) -> Font {
        Font(size: size, weight: weight)
    }

    // MARK: - Preset text styles (macOS sizes)

    /// 34pt bold — large title
    public static let largeTitle = Font(size: 34, weight: .regular)
    /// 28pt regular — title
    public static let title = Font(size: 28, weight: .regular)
    /// 22pt regular — title 2
    public static let title2 = Font(size: 22, weight: .regular)
    /// 20pt regular — title 3
    public static let title3 = Font(size: 20, weight: .regular)
    /// 17pt semibold — headline
    public static let headline = Font(size: 17, weight: .semibold)
    /// 17pt regular — body
    public static let body = Font(size: 17, weight: .regular)
    /// 16pt regular — callout
    public static let callout = Font(size: 16, weight: .regular)
    /// 15pt regular — subheadline
    public static let subheadline = Font(size: 15, weight: .regular)
    /// 13pt regular — footnote
    public static let footnote = Font(size: 13, weight: .regular)
    /// 12pt regular — caption
    public static let caption = Font(size: 12, weight: .regular)
    /// 11pt regular — caption 2
    public static let caption2 = Font(size: 11, weight: .regular)

    // MARK: - Internal conversion

    /// Convert to the internal FontWeight used by ViewNode.
    internal var internalWeight: FontWeight {
        if weight.value >= Weight.bold.value { return .bold }
        if weight.value >= Weight.semibold.value { return .semibold }
        if weight.value >= Weight.medium.value { return .medium }
        return .regular
    }
}

// MARK: - Bold variant

extension Font {
    /// Returns a bold version of this font.
    public func bold() -> Font {
        Font(size: size, weight: .bold)
    }

    /// Returns a version with the specified weight.
    public func weight(_ weight: Weight) -> Font {
        Font(size: size, weight: weight)
    }
}
