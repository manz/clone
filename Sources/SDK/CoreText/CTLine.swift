import Foundation

/// A single shaped line of text, matching Apple's CoreText CTLine.
public final class CTLine {
    internal let text: String
    internal let font: CTFont

    private var _cachedWidth: CGFloat?

    internal init(text: String, font: CTFont) {
        self.text = text
        self.font = font
    }

    /// Measure width lazily via Rust FFI (no maxWidth — CTLine is single-line).
    internal var measuredWidth: CGFloat {
        if let cached = _cachedWidth { return cached }
        guard !text.isEmpty else { return 0 }
        let result = measureText(content: text, fontSize: Float(font.size), weight: font.weight, maxWidth: nil)
        let w = CGFloat(result.width)
        _cachedWidth = w
        return w
    }
}

// MARK: - Free functions (Apple CoreText API)

/// Create a CTLine from text and a font.
public func CTLineCreate(_ text: String, font: CTFont) -> CTLine {
    CTLine(text: text, font: font)
}

/// Returns the typographic width of the line.
/// Fills ascent, descent, leading pointers from the font metrics.
public func CTLineGetTypographicBounds(
    _ line: CTLine,
    _ ascent: UnsafeMutablePointer<CGFloat>?,
    _ descent: UnsafeMutablePointer<CGFloat>?,
    _ leading: UnsafeMutablePointer<CGFloat>?
) -> Double {
    ascent?.pointee = line.font.ascent
    descent?.pointee = line.font.descent
    leading?.pointee = line.font.leading
    return Double(line.measuredWidth)
}

/// Find the character index closest to the given position.
public func CTLineGetStringIndexForPosition(_ line: CTLine, _ position: CGPoint) -> CFIndex {
    guard !line.text.isEmpty else { return 0 }
    // Walk glyphs to find the character whose x-offset is closest to position.x
    var bestIndex = 0
    var bestDist = CGFloat.greatestFiniteMagnitude
    for i in 0...line.text.count {
        let pos = cursorPosition(
            content: line.text,
            charOffset: UInt32(i),
            fontSize: Float(line.font.size),
            weight: line.font.weight,
            maxWidth: nil
        )
        let dist = abs(CGFloat(pos.x) - position.x)
        if dist < bestDist {
            bestDist = dist
            bestIndex = i
        }
    }
    return bestIndex
}

/// Returns the x-offset for the given character index.
public func CTLineGetOffsetForStringIndex(
    _ line: CTLine,
    _ charIndex: CFIndex,
    _ secondaryOffset: UnsafeMutablePointer<CGFloat>?
) -> CGFloat {
    guard !line.text.isEmpty else { return 0 }
    let clamped = max(0, min(charIndex, line.text.count))
    let pos = cursorPosition(
        content: line.text,
        charOffset: UInt32(clamped),
        fontSize: Float(line.font.size),
        weight: line.font.weight,
        maxWidth: nil
    )
    let offset = CGFloat(pos.x)
    secondaryOffset?.pointee = offset
    return offset
}
