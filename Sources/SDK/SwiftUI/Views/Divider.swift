import Foundation

/// A visual element that creates a horizontal line separator.
/// Matches Apple's SwiftUI `Divider` struct.
public struct Divider: _PrimitiveView {
    public init() {}

    public var _nodeRepresentation: ViewNode {
        .rect(width: nil, height: 1, fill: WindowChrome.overlay)
    }
}
