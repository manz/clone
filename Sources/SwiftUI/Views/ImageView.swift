import Foundation

/// A view that displays an image. Matches Apple's SwiftUI `Image` struct.
/// Currently renders as a colored placeholder rect (no real image loading).
public struct Image: View {
    let name: String

    /// `Image(systemName:)` — SF Symbol stub.
    public init(systemName: String) {
        self.name = systemName
    }

    /// `Image(_:)` — named image.
    public init(_ name: String) {
        self.name = name
    }

    public var body: ViewNode {
        .image(name: name, width: nil, height: nil)
    }
}
