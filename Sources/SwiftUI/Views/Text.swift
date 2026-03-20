import Foundation

/// A view that displays one or more lines of read-only text.
/// Matches Apple's SwiftUI `Text` struct.
public struct Text: View {
    var content: String
    var fontSize: CGFloat = 14
    var color: Color = .primary
    var fontWeight: FontWeight = .regular

    public init(_ content: String) {
        self.content = content
    }

    public var body: ViewNode {
        .text(content, fontSize: fontSize, color: color, weight: fontWeight)
    }

    // MARK: - Text-specific modifiers (return Text for type-safe chaining)

    /// `.font(.headline)` / `.font(.system(size: 14, weight: .semibold))`
    public func font(_ font: Font) -> Text {
        var copy = self
        copy.fontSize = font.size
        copy.fontWeight = font.internalWeight
        return copy
    }

    /// `.bold()` — sets font weight to bold.
    public func bold() -> Text {
        var copy = self
        copy.fontWeight = .bold
        return copy
    }

    /// `.italic()` — no-op for now (no italic support in renderer yet).
    public func italic() -> Text {
        self
    }

    /// `.foregroundColor(.white)` — sets the text color.
    public func foregroundColor(_ color: Color) -> Text {
        var copy = self
        copy.color = color
        return copy
    }

    /// `.fontWeight(.semibold)` — sets text weight. Matches Apple's SwiftUI.
    public func fontWeight(_ weight: Font.Weight) -> Text {
        var copy = self
        copy.fontWeight = Font(size: fontSize, weight: weight).internalWeight
        return copy
    }

    /// `.foregroundStyle(_:)` — alias for foregroundColor.
    public func foregroundStyle(_ color: Color) -> Text {
        foregroundColor(color)
    }

    /// `.strikethrough()` — no-op for now.
    public func strikethrough(_ active: Bool = true, color: Color? = nil) -> Text { self }

    /// `.underline()` — no-op for now.
    public func underline(_ active: Bool = true, color: Color? = nil) -> Text { self }

    /// `.lineLimit(_:)` — no-op for now.
    public func lineLimit(_ limit: Int?) -> Text { self }

    /// `.lineSpacing(_:)` — no-op for now.
    public func lineSpacing(_ spacing: CGFloat) -> Text { self }

    /// Text truncation mode.
    public enum TruncationMode { case head, tail, middle }

    /// Text case transformation.
    public enum Case { case uppercase, lowercase }

    /// `Text + Text` — concatenates two text views.
    public static func + (lhs: Text, rhs: Text) -> Text {
        var result = Text(lhs.content + rhs.content)
        result.fontSize = lhs.fontSize
        result.color = lhs.color
        result.fontWeight = lhs.fontWeight
        return result
    }
}

// MARK: - LocalizedStringKey

/// A key used to look up a localized string. On Clone, just wraps the string.
public struct LocalizedStringKey: ExpressibleByStringLiteral, ExpressibleByStringInterpolation, Sendable {
    public let key: String
    public init(_ value: String) { self.key = value }
    public init(stringLiteral value: String) { self.key = value }
}

extension Text {
    /// `Text(LocalizedStringKey)` — creates text from a localized string key.
    public init(_ key: LocalizedStringKey) {
        self.init(key.key)
    }
}
