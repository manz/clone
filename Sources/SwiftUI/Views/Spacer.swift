import Foundation

/// A flexible space that expands along the major axis of its containing
/// stack layout. Matches Apple's SwiftUI `Spacer` struct.
public struct Spacer: View {
    public let minLength: CGFloat

    public init(minLength: CGFloat = 0) {
        self.minLength = minLength
    }

    public var body: ViewNode {
        .spacer(minLength: minLength)
    }
}
