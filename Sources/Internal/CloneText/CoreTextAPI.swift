import Foundation

/// CT-prefixed aliases for use in SwiftUI (avoids collision with generated names).
public typealias CTFontWeight = FontWeight
public typealias CTTextSize = TextSize

/// Convenience wrapper for text measurement and cursor positioning.
public enum CTTextMeasurer {
    public static func measure(_ text: String, fontSize: CGFloat, weight: FontWeight, maxWidth: Float? = nil) -> TextSize {
        measureText(content: text, fontSize: Float(fontSize), weight: weight, maxWidth: maxWidth)
    }

    public static func cursorPos(_ text: String, charOffset: Int, fontSize: CGFloat, weight: FontWeight, maxWidth: Float? = nil) -> CursorPosition {
        cursorPosition(content: text, charOffset: UInt32(charOffset), fontSize: Float(fontSize), weight: weight, maxWidth: maxWidth)
    }
}
