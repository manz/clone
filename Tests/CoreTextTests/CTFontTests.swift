import Testing
@testable import CoreText

@Suite("CTFont")
struct CTFontTests {
    @Test func createWithName() {
        let font = CTFontCreateWithName("Inter" as CFString, 16, nil)
        #expect(CTFontGetSize(font) == 16)
        #expect(CTFontCopyFamilyName(font) as String == "Inter")
    }

    @Test func metricsProportionalToSize() {
        let small = CTFontCreateWithName("Inter" as CFString, 12, nil)
        let large = CTFontCreateWithName("Inter" as CFString, 24, nil)
        #expect(CTFontGetAscent(large) == CTFontGetAscent(small) * 2)
        #expect(CTFontGetDescent(large) == CTFontGetDescent(small) * 2)
    }

    @Test func ascentDescentSumApproximatesSize() {
        let font = CTFontCreateWithName("Inter" as CFString, 16, nil)
        let sum = CTFontGetAscent(font) + CTFontGetDescent(font)
        // Inter: (1848+488)/2048 = 1.140625 ratio, so sum ≈ 18.25 for size 16
        #expect(sum > font.size)
        #expect(sum < font.size * 1.5)
    }

    @Test func leadingIsZero() {
        let font = CTFontCreateWithName("Inter" as CFString, 14, nil)
        #expect(CTFontGetLeading(font) == 0)
    }

    @Test func createWithDescriptor() {
        let desc = CTFontDescriptorCreateWithNameAndSize("Inter" as CFString, 20)
        let font = CTFontCreateWithFontDescriptor(desc, 20, nil)
        #expect(CTFontGetSize(font) == 20)
        #expect(CTFontCopyFamilyName(font) as String == "Inter")
    }
}
