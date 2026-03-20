import Foundation

/// A rectangular shape with rounded corners, aligned inside the frame of
/// the view containing it. Matches Apple's SwiftUI `RoundedRectangle` struct.
/// The style of a rounded rectangle's corners.
public enum RoundedCornerStyle: Sendable {
    case circular
    case continuous
}

public struct RoundedRectangle: Shape {
    public let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
    }

    public init(cornerRadius: CGFloat, style: RoundedCornerStyle) {
        self.cornerRadius = cornerRadius
    }

    public init(cornerSize: CGSize, style: RoundedCornerStyle = .circular) {
        self.cornerRadius = min(cornerSize.width, cornerSize.height)
    }

    public func path(in rect: LayoutFrame) -> ViewNode {
        .roundedRect(width: rect.width, height: rect.height, radius: cornerRadius, fill: .white)
    }

    public func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        return p
    }

    public var body: ViewNode {
        .roundedRect(width: nil, height: nil, radius: cornerRadius, fill: .white)
    }
}
