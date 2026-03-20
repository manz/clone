import Foundation

/// A visual element that creates a horizontal line separator.
/// Matches Apple's SwiftUI `Divider` struct.
public struct Divider: View {
    public init() {}

    public var body: ViewNode {
        .rect(width: nil, height: 1, fill: WindowChrome.overlay)
    }
}
