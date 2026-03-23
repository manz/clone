import Foundation
import CoreText

/// Measures text size using cosmic-text via the CoreText bridge module.
enum TextMeasurer {
    static func measure(_ text: String, fontSize: CGFloat, weight: FontWeight) -> CGSize {
        let ctWeight: CTFontWeight = switch weight {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
        let size = CTTextMeasurer.measure(text, fontSize: fontSize, weight: ctWeight)
        return CGSize(width: size.width, height: size.height)
    }

    static func measureIcon(_ text: String, fontSize: CGFloat) -> CGSize {
        let size = CTTextMeasurer.measure(text, fontSize: fontSize, weight: .regular, isIcon: true)
        return CGSize(width: size.width, height: size.height)
    }
}
