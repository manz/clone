import Testing
@testable import CoreText

@Suite("CTRun")
struct CTRunTests {
    @Test func runFromFrame() {
        let font = CTFontCreateWithName("Inter" as CFString, 14, nil)
        let framesetter = CTFramesetterCreate("Hello world", font: font)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), CGSize(width: 500, height: 500))
        let lines = CTFrameGetLines(frame)
        #expect(!lines.isEmpty)

        let runs = CTLineGetGlyphRuns(lines[0])
        #expect(!runs.isEmpty)

        let run = runs[0]
        #expect(CTRunGetGlyphCount(run) > 0)
    }

    @Test func runStringRange() {
        let font = CTFontCreateWithName("Inter" as CFString, 14, nil)
        let framesetter = CTFramesetterCreate("Hello", font: font)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), CGSize(width: 500, height: 500))
        let lines = CTFrameGetLines(frame)
        let runs = CTLineGetGlyphRuns(lines[0])
        let range = CTRunGetStringRange(runs[0])
        #expect(range.location >= 0)
        #expect(range.length > 0)
    }

    @Test func runPositions() {
        let font = CTFontCreateWithName("Inter" as CFString, 14, nil)
        let framesetter = CTFramesetterCreate("AB", font: font)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), CGSize(width: 500, height: 500))
        let lines = CTFrameGetLines(frame)
        let runs = CTLineGetGlyphRuns(lines[0])
        let run = runs[0]
        let count = CTRunGetGlyphCount(run)
        guard count >= 2 else { return }

        var positions = [CGPoint](repeating: CGPoint(x: 0, y: 0), count: count)
        CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
        // Second glyph should be to the right of first
        #expect(positions[1].x > positions[0].x)
    }

    @Test func runAdvances() {
        let font = CTFontCreateWithName("Inter" as CFString, 14, nil)
        let framesetter = CTFramesetterCreate("Hi", font: font)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), CGSize(width: 500, height: 500))
        let lines = CTFrameGetLines(frame)
        let runs = CTLineGetGlyphRuns(lines[0])
        let run = runs[0]
        let count = CTRunGetGlyphCount(run)
        guard count >= 1 else { return }

        var advances = [CGSize](repeating: CGSize(width: 0, height: 0), count: count)
        CTRunGetAdvances(run, CFRange(location: 0, length: 0), &advances)
        #expect(advances[0].width > 0)
    }
}
