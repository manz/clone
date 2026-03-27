import Foundation

/// Minimal font descriptor stub — typed fields, no `Any` dictionary.
/// Phase 3 will add real font matching.
public final class CTFontDescriptor {
    public let name: String?
    public let size: CGFloat
    public let weight: FontWeight?

    internal init(name: String?, size: CGFloat, weight: FontWeight? = nil) {
        self.name = name
        self.size = size
        self.weight = weight
    }
}

// MARK: - Free functions

public func CTFontDescriptorCreateWithNameAndSize(_ name: CFString, _ size: CGFloat) -> CTFontDescriptor {
    CTFontDescriptor(name: name as String, size: size)
}
