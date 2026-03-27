import Testing
@testable import CoreText

@Suite("CTLine")
struct CTLineTests {
    @Test func typographicBoundsPositiveWidth() {
        let font = CTFontCreateWithName("Inter" as CFString, 14, nil)
        let line = CTLineCreate("Hello, world!", font: font)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        #expect(width > 0)
        #expect(ascent > 0)
        #expect(descent > 0)
        #expect(leading == 0)
    }

    @Test func emptyTextZeroWidth() {
        let font = CTFontCreateWithName("Inter" as CFString, 14, nil)
        let line = CTLineCreate("", font: font)
        let width = CTLineGetTypographicBounds(line, nil, nil, nil)
        #expect(width == 0)
    }

    @Test func stringIndexAtOrigin() {
        let font = CTFontCreateWithName("Inter" as CFString, 14, nil)
        let line = CTLineCreate("Hello", font: font)
        let index = CTLineGetStringIndexForPosition(line, CGPoint(x: 0, y: 0))
        #expect(index == 0)
    }

    @Test func offsetAtIndexZero() {
        let font = CTFontCreateWithName("Inter" as CFString, 14, nil)
        let line = CTLineCreate("Hello", font: font)
        let offset = CTLineGetOffsetForStringIndex(line, 0, nil)
        #expect(offset == 0)
    }

    @Test func offsetAtEndApproximatesWidth() {
        let font = CTFontCreateWithName("Inter" as CFString, 14, nil)
        let text = "Hello"
        let line = CTLineCreate(text, font: font)
        let width = CTLineGetTypographicBounds(line, nil, nil, nil)
        let offset = CTLineGetOffsetForStringIndex(line, text.count, nil)
        // End-of-string offset should be close to the measured width
        #expect(abs(Double(offset) - width) < 2.0)
    }
}
