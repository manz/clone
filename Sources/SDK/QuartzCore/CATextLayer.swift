import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#else
import CloneCoreGraphics
#endif

// MARK: - CATextLayer

open class CATextLayer: CALayer {
    open var string: Any?  // String or NSAttributedString
    open var font: Any?    // CTFont, CGFont, or String
    open var fontSize: CGFloat = 36
    open var foregroundColor: CGColor?
    open var isWrapped: Bool = false
    open var truncationMode: CATextLayerTruncationMode = .none
    open var alignmentMode: CATextLayerAlignmentMode = .natural
    open var allowsFontSubpixelQuantization: Bool = true
}

public struct CATextLayerTruncationMode: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let none = CATextLayerTruncationMode(rawValue: "none")
    public static let start = CATextLayerTruncationMode(rawValue: "start")
    public static let end = CATextLayerTruncationMode(rawValue: "end")
    public static let middle = CATextLayerTruncationMode(rawValue: "middle")
}

public struct CATextLayerAlignmentMode: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let natural = CATextLayerAlignmentMode(rawValue: "natural")
    public static let left = CATextLayerAlignmentMode(rawValue: "left")
    public static let right = CATextLayerAlignmentMode(rawValue: "right")
    public static let center = CATextLayerAlignmentMode(rawValue: "center")
    public static let justified = CATextLayerAlignmentMode(rawValue: "justified")
}
