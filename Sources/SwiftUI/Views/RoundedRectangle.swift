import Foundation

/// A rectangular shape with rounded corners, aligned inside the frame of
/// the view containing it. Matches Apple's SwiftUI `RoundedRectangle` struct.
public struct RoundedRectangle: View {
    public let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
    }

    public var body: ViewNode {
        .roundedRect(width: nil, height: nil, radius: cornerRadius, fill: .white)
    }
}
