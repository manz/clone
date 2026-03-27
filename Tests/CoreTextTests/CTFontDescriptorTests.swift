import Testing
@testable import CoreText

@Suite("CTFontDescriptor")
struct CTFontDescriptorTests {
    @Test func interResolvesSuccessfully() {
        let desc = CTFontDescriptorCreateWithNameAndSize("Inter" as CFString, 14)
        #expect(desc.name == "Inter")
        #expect(desc.matched == true)
    }

    @Test func unknownFontFallsBackToInter() {
        let desc = CTFontDescriptorCreateWithNameAndSize("NonExistentFont99" as CFString, 14)
        #expect(desc.name == "Inter")
        #expect(desc.matched == false)
    }

    @Test func matchingReturnsNilForUnmatched() {
        let desc = CTFontDescriptorCreateWithNameAndSize("NonExistentFont99" as CFString, 14)
        let match = CTFontDescriptorCreateMatchingFontDescriptor(desc, nil)
        #expect(match == nil)
    }

    @Test func matchingReturnsDescriptorForMatched() {
        let desc = CTFontDescriptorCreateWithNameAndSize("Inter" as CFString, 14)
        let match = CTFontDescriptorCreateMatchingFontDescriptor(desc, nil)
        #expect(match != nil)
    }

    @Test func fontFromDescriptor() {
        let desc = CTFontDescriptorCreateWithNameAndSize("Inter" as CFString, 20)
        let font = CTFontCreateWithFontDescriptor(desc, 20, nil)
        #expect(CTFontGetSize(font) == 20)
        #expect(CTFontCopyFamilyName(font) as String == "Inter")
    }
}
