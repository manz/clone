import Foundation
import CloneText

/// Measures text size using cosmic-text via the CoreText bridge module.
/// Caches results on the Swift side to avoid repeated FFI calls.
enum TextMeasurer {
    nonisolated(unsafe) private static var cache: [UInt64: CGSize] = [:]

    private static func cacheKey(_ text: String, _ fontSize: CGFloat, _ weight: FontWeight, _ isIcon: Bool) -> UInt64 {
        var hasher = Hasher()
        hasher.combine(text)
        hasher.combine(fontSize)
        hasher.combine(weight)
        hasher.combine(isIcon)
        return UInt64(bitPattern: Int64(hasher.finalize()))
    }

    static func measure(_ text: String, fontSize: CGFloat, weight: FontWeight) -> CGSize {
        guard !text.isEmpty else { return CGSize(width: 0, height: fontSize * 1.2) }
        let key = cacheKey(text, fontSize, weight, false)
        if let cached = cache[key] { return cached }

        let result = CTTextMeasurer.measure(text, fontSize: fontSize, weight: weight)
        let size = CGSize(width: CGFloat(result.width), height: CGFloat(result.height))
        cache[key] = size
        return size
    }

    static func measureIcon(_ text: String, fontSize: CGFloat) -> CGSize {
        guard !text.isEmpty else { return CGSize(width: fontSize, height: fontSize) }
        let key = cacheKey(text, fontSize, .regular, true)
        if let cached = cache[key] { return cached }

        let result = CTTextMeasurer.measure(text, fontSize: fontSize, weight: .regular, isIcon: true)
        let size = CGSize(width: CGFloat(result.width), height: CGFloat(result.height))
        cache[key] = size
        return size
    }
}
