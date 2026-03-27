import Testing
@testable import CoreText

@Suite("CTFrame")
struct CTFrameTests {
    @Test func frameCreationWithWrapping() {
        let font = CTFontCreateWithName("Inter" as CFString, 14, nil)
        let framesetter = CTFramesetterCreate("Hello world this is a long line that should wrap", font: font)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), CGSize(width: 100, height: 1000))
        let lines = CTFrameGetLines(frame)
        #expect(lines.count >= 1)
    }

    @Test func frameLineOrigins() {
        let font = CTFontCreateWithName("Inter" as CFString, 14, nil)
        let framesetter = CTFramesetterCreate("Line one\nLine two\nLine three", font: font)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), CGSize(width: 500, height: 1000))
        let lines = CTFrameGetLines(frame)
        #expect(lines.count >= 1)

        var origins = [CGPoint](repeating: CGPoint(x: 0, y: 0), count: lines.count)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)
        // First line origin should be at y=0
        #expect(origins[0].y == 0)
        // Subsequent lines should have increasing y
        if lines.count > 1 {
            #expect(origins[1].y > origins[0].y)
        }
    }

    @Test func suggestFrameSize() {
        let font = CTFontCreateWithName("Inter" as CFString, 14, nil)
        let framesetter = CTFramesetterCreate("Hello world", font: font)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: 0),
            CGSize(width: 500, height: 500),
            nil
        )
        #expect(size.width > 0)
        #expect(size.height > 0)
    }
}
