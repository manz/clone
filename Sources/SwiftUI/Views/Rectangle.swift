import Foundation

/// A rectangular shape aligned inside the frame of the view containing it.
/// Matches Apple's SwiftUI `Rectangle` struct.
public struct Rectangle: Shape {
    public init() {}

    public func path(in rect: LayoutFrame) -> ViewNode {
        .rect(width: rect.width, height: rect.height, fill: .white)
    }

    public func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRect(rect)
        return p
    }

    public var body: ViewNode {
        .rect(width: nil, height: nil, fill: .white)
    }
}
