import Foundation

/// A flexible space that expands along the major axis of its containing
/// stack layout. Matches Apple's SwiftUI `Spacer` struct.
public struct Spacer: _PrimitiveView {
    public let minLength: CGFloat

    public init(minLength: CGFloat = 0) {
        self.minLength = minLength
    }

    public var _nodeRepresentation: ViewNode {
        .spacer(minLength: minLength)
    }
}
