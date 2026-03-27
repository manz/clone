import Foundation

/// Returns an array of all available font family names, sorted alphabetically.
/// Matches Apple's `CTFontManagerCopyAvailableFontFamilyNames()`.
public func CTFontManagerCopyAvailableFontFamilyNames() -> [String] {
    listFontFamilies()
}
