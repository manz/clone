import Foundation

/// Measures text size.
/// TODO: Replace with cosmic-text measurement via UniFFI for accurate cross-platform sizing.
/// For now uses a heuristic approximation.
enum TextMeasurer {
    static func measure(_ text: String, fontSize: CGFloat, weight: FontWeight) -> CGSize {
        guard !text.isEmpty else { return CGSize(width: 0, height: fontSize * 1.2) }
        // Approximation — will be replaced by cosmic-text measurement bridge
        let factor: CGFloat = switch weight {
        case .bold: 0.62
        case .semibold: 0.58
        case .medium: 0.55
        case .regular: 0.52
        }
        let width = fontSize * factor * CGFloat(text.count)
        return CGSize(width: width, height: fontSize * 1.2)
    }
}
