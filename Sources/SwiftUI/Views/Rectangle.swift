import Foundation

/// A rectangular shape aligned inside the frame of the view containing it.
/// Matches Apple's SwiftUI `Rectangle` struct.
public struct Rectangle: View {
    public init() {}

    public var body: ViewNode {
        .rect(width: nil, height: nil, fill: .white)
    }
}
