import Foundation

/// A contiguous run of glyphs with identical attributes within a CTLine.
public final class CTRun {
    internal let glyphs: [GlyphInfo]
    internal let stringRange: CFRange
    internal let font: CTFont

    internal init(glyphs: [GlyphInfo], stringRange: CFRange, font: CTFont) {
        self.glyphs = glyphs
        self.stringRange = stringRange
        self.font = font
    }
}

// MARK: - Free functions (Apple CoreText API)

public func CTRunGetGlyphCount(_ run: CTRun) -> CFIndex {
    run.glyphs.count
}

/// Fill the positions array with glyph x-positions for the given range.
public func CTRunGetPositions(_ run: CTRun, _ range: CFRange, _ positions: UnsafeMutablePointer<CGPoint>) {
    let start = range.location == 0 && range.length == 0 ? 0 : range.location
    let count = range.length == 0 ? run.glyphs.count : range.length
    for i in 0..<count {
        let idx = start + i
        if idx < run.glyphs.count {
            positions[i] = CGPoint(x: CGFloat(run.glyphs[idx].x), y: 0)
        }
    }
}

public func CTRunGetStringRange(_ run: CTRun) -> CFRange {
    run.stringRange
}

/// Fill the advances array with per-glyph advance widths.
public func CTRunGetAdvances(_ run: CTRun, _ range: CFRange, _ advances: UnsafeMutablePointer<CGSize>) {
    let start = range.location == 0 && range.length == 0 ? 0 : range.location
    let count = range.length == 0 ? run.glyphs.count : range.length
    for i in 0..<count {
        let idx = start + i
        if idx < run.glyphs.count {
            advances[i] = CGSize(width: CGFloat(run.glyphs[idx].width), height: 0)
        }
    }
}
