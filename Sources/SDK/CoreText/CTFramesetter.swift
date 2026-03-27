import Foundation

/// Framesetter for multi-line text layout using Rust cosmic-text.
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

/// Create a CTFrame by laying out text into wrapped lines with glyph data.
public func CTFramesetterCreateFrame(
    _ framesetter: CTFramesetter,
    _ stringRange: CFRange,
    _ constraints: CGSize
) -> CTFrame {
    let maxWidth = Float(constraints.width > 0 ? constraints.width : 10000)
    let layout = layoutText(
        content: framesetter.text,
        fontSize: Float(framesetter.font.size),
        weight: framesetter.font.weight,
        maxWidth: maxWidth
    )

    var lines: [CTLine] = []
    var origins: [CGPoint] = []

    for layoutLine in layout.lines {
        // Extract the substring for this line
        let startIdx = framesetter.text.index(
            framesetter.text.startIndex,
            offsetBy: min(Int(layoutLine.stringRangeStart), framesetter.text.count)
        )
        let endIdx = framesetter.text.index(
            framesetter.text.startIndex,
            offsetBy: min(Int(layoutLine.stringRangeEnd), framesetter.text.count)
        )
        let lineText = String(framesetter.text[startIdx..<endIdx])

        let line = CTLineCreate(lineText, font: framesetter.font)
        // Attach run data from the layout
        line._runs = [CTRun(
            glyphs: layoutLine.glyphs,
            stringRange: CFRange(
                location: Int(layoutLine.stringRangeStart),
                length: Int(layoutLine.stringRangeEnd) - Int(layoutLine.stringRangeStart)
            ),
            font: framesetter.font
        )]

        lines.append(line)
        origins.append(CGPoint(x: 0, y: CGFloat(layoutLine.originY)))
    }

    return CTFrame(lines: lines, lineOrigins: origins)
}
