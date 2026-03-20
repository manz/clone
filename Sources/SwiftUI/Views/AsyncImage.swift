import Foundation

/// The current phase of an asynchronous image loading operation.
public enum AsyncImagePhase {
    case empty
    case success(Image)
    case failure(Error)
}

/// A view that asynchronously loads and displays an image.
/// On Clone, this always shows the placeholder (no network loading).
public struct AsyncImage<Content: View>: View {
    let content: ViewNode

    /// Creates an async image with a URL. Shows a gray placeholder.
    public init(url: URL?, scale: CGFloat = 1) {
        self.content = ViewNode.rect(width: nil, height: nil, fill: Color(white: 0.5, opacity: 0.2))
    }

    /// Creates an async image with a custom content/placeholder builder.
    public init(
        url: URL?,
        scale: CGFloat = 1,
        @ViewBuilder content: @escaping (Image) -> some View,
        @ViewBuilder placeholder: () -> some View
    ) {
        self.content = _resolve(placeholder())
    }

    /// Creates an async image with a phase-based builder.
    public init(
        url: URL?,
        scale: CGFloat = 1,
        transaction: Any? = nil,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> some View
    ) {
        self.content = _resolve(content(.empty))
    }

    public var body: ViewNode {
        content
    }
}
