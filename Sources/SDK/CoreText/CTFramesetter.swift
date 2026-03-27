import Foundation

/// Minimal framesetter for multi-line text measurement.
/// Phase 2 will add full CTFrame/CTRun support.
public final class CTFramesetter {
    internal let text: String
    internal let font: CTFont

    internal init(text: String, font: CTFont) {
        self.text = text
        self.font = font
    }
}

// MARK: - Free functions

public func CTFramesetterCreate(_ text: String, font: CTFont) -> CTFramesetter {
    CTFramesetter(text: text, font: font)
}

/// Suggest the size needed to lay out the text within the given constraints.
/// Word wrapping respects word boundaries (cosmic-text default).
public func CTFramesetterSuggestFrameSizeWithConstraints(
    _ framesetter: CTFramesetter,
    _ stringRange: CFRange,
    _ constraints: CGSize,
    _ fitRange: UnsafeMutablePointer<CFRange>?
) -> CGSize {
    let maxWidth: Float? = constraints.width > 0 && constraints.width < CGFloat.greatestFiniteMagnitude
        ? Float(constraints.width)
        : nil
    let result = measureText(
        content: framesetter.text,
        fontSize: Float(framesetter.font.size),
        weight: framesetter.font.weight,
        maxWidth: maxWidth
    )
    fitRange?.pointee = CFRange(location: 0, length: framesetter.text.count)
    return CGSize(width: CGFloat(result.width), height: CGFloat(result.height))
}
