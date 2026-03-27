import Foundation

/// Font descriptor with typed fields — queries Rust font database for matching.
public final class CTFontDescriptor {
    public let name: String?
    public let size: CGFloat
    public let weight: FontWeight?

    /// Whether the requested font family was found in the font database.
    public let matched: Bool

    internal init(name: String?, size: CGFloat, weight: FontWeight? = nil) {
        self.size = size
        self.weight = weight
        if let name = name {
            let info = resolveFont(family: name, weight: weight ?? .regular)
            self.name = info.family
            self.matched = info.available
        } else {
            self.name = nil
            self.matched = false
        }
    }
}

// MARK: - Free functions

public func CTFontDescriptorCreateWithNameAndSize(_ name: CFString, _ size: CGFloat) -> CTFontDescriptor {
    CTFontDescriptor(name: name as String, size: size)
}

/// Find the best matching font descriptor for the given attributes.
public func CTFontDescriptorCreateMatchingFontDescriptor(
    _ descriptor: CTFontDescriptor,
    _ mandatoryAttributes: Set<String>?
) -> CTFontDescriptor? {
    guard descriptor.matched else { return nil }
    return descriptor
}
