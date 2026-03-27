import Foundation

/// An opaque font reference matching Apple's CoreText CTFont.
/// Phase 1: metrics hardcoded to Inter.
public final class CTFont {
    public let familyName: String
    public let size: CGFloat
    public let weight: FontWeight

    // Inter metrics: ascender=1848, descender=488, unitsPerEm=2048
    private static let ascenderRatio: CGFloat = 1848.0 / 2048.0
    private static let descenderRatio: CGFloat = 488.0 / 2048.0

    public var ascent: CGFloat { size * CTFont.ascenderRatio }
    public var descent: CGFloat { size * CTFont.descenderRatio }
    public var leading: CGFloat { 0 }
    public var lineHeight: CGFloat { ascent + descent + leading }

    internal init(name: String, size: CGFloat, weight: FontWeight) {
        self.familyName = name
        self.size = size
        self.weight = weight
    }
}

// MARK: - Free functions (Apple CoreText API)

public func CTFontCreateWithName(_ name: CFString, _ size: CGFloat, _ matrix: UnsafePointer<CGAffineTransform>?) -> CTFont {
    CTFont(name: name as String, size: size, weight: .regular)
}

public func CTFontCreateWithFontDescriptor(_ descriptor: CTFontDescriptor, _ size: CGFloat, _ matrix: UnsafePointer<CGAffineTransform>?) -> CTFont {
    CTFont(name: descriptor.name ?? "Inter", size: size, weight: descriptor.weight ?? .regular)
}

public func CTFontGetSize(_ font: CTFont) -> CGFloat {
    font.size
}

public func CTFontGetAscent(_ font: CTFont) -> CGFloat {
    font.ascent
}

public func CTFontGetDescent(_ font: CTFont) -> CGFloat {
    font.descent
}

public func CTFontGetLeading(_ font: CTFont) -> CGFloat {
    font.leading
}

public func CTFontCopyFamilyName(_ font: CTFont) -> CFString {
    font.familyName as CFString
}
