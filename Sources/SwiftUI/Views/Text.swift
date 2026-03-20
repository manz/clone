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
}
