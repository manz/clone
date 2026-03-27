import Foundation

/// A frame of laid-out text — contains an array of CTLine objects (one per visual line after wrapping).
public final class CTFrame {
    public let lines: [CTLine]
    public let lineOrigins: [CGPoint]

    internal init(lines: [CTLine], lineOrigins: [CGPoint]) {
        self.lines = lines
        self.lineOrigins = lineOrigins
    }
}

// MARK: - Free functions (Apple CoreText API)

public func CTFrameGetLines(_ frame: CTFrame) -> [CTLine] {
    frame.lines
}

/// Fill the origins array with the origin point of each line in the frame.
public func CTFrameGetLineOrigins(_ frame: CTFrame, _ range: CFRange, _ origins: UnsafeMutablePointer<CGPoint>) {
    let start = range.location == 0 && range.length == 0 ? 0 : range.location
    let count = range.length == 0 ? frame.lineOrigins.count : range.length
    for i in 0..<count {
        let idx = start + i
        if idx < frame.lineOrigins.count {
            origins[i] = frame.lineOrigins[idx]
        }
    }
}
