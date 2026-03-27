import Foundation

/// Measures text size using cosmic-text via the CoreText bridge module.
/// Caching is handled by the Rust side (FxHashMap in clone-text).
public enum TextMeasurer {
    /// Measure text, optionally with word wrapping at maxWidth.
    public static func measure(_ text: String, fontSize: CGFloat, weight: FontWeight, maxWidth: CGFloat? = nil) -> CGSize {
        guard !text.isEmpty else { return CGSize(width: 0, height: fontSize * 1.2) }
        let mw: Float? = maxWidth.map { Float($0) }
        let result = measureText(content: text, fontSize: Float(fontSize), weight: weight, maxWidth: mw)
        return CGSize(width: CGFloat(result.width), height: CGFloat(result.height))
    }

    /// Cursor position within a (possibly wrapped) text block.
    /// Returns (x, y) relative to the text block's top-left, plus line height.
    public static func cursorPosition(
        in text: String,
        at charOffset: Int,
        fontSize: CGFloat,
        weight: FontWeight = .regular,
        maxWidth: CGFloat? = nil
    ) -> (x: CGFloat, y: CGFloat, height: CGFloat) {
        guard !text.isEmpty else {
            return (0, 0, fontSize * 1.2)
        }
        let mw: Float? = maxWidth.map { Float($0) }
        let pos = CloneText.cursorPosition(content: text, charOffset: UInt32(charOffset), fontSize: Float(fontSize), weight: weight, maxWidth: mw)
        return (CGFloat(pos.x), CGFloat(pos.y), CGFloat(pos.height))
    }
}
