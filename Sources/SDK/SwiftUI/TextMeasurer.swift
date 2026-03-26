import Foundation
import CloneText

/// Measures text size using cosmic-text via the CoreText bridge module.
/// Caches results on the Swift side to avoid repeated FFI calls.
enum TextMeasurer {
    nonisolated(unsafe) private static var cache: [UInt64: CGSize] = [:]

    private static func cacheKey(_ text: String, _ fontSize: CGFloat, _ weight: FontWeight, _ maxWidth: CGFloat?) -> UInt64 {
        var hasher = Hasher()
        hasher.combine(text)
        hasher.combine(fontSize)
        hasher.combine(weight)
        hasher.combine(maxWidth)
        return UInt64(bitPattern: Int64(hasher.finalize()))
    }

    /// Measure text, optionally with word wrapping at maxWidth.
    static func measure(_ text: String, fontSize: CGFloat, weight: FontWeight, maxWidth: CGFloat? = nil) -> CGSize {
        guard !text.isEmpty else { return CGSize(width: 0, height: fontSize * 1.2) }
        let key = cacheKey(text, fontSize, weight, maxWidth)
        if let cached = cache[key] { return cached }

        let mw: Float? = maxWidth.map { Float($0) }
        let result = CTTextMeasurer.measure(text, fontSize: fontSize, weight: weight, maxWidth: mw)
        let size = CGSize(width: CGFloat(result.width), height: CGFloat(result.height))
        cache[key] = size
        return size
    }
}
