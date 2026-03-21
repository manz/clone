import Foundation

/// A view that displays an image. Matches Apple's SwiftUI `Image` struct.
/// Currently renders as a colored placeholder rect (no real image loading).
public struct Image: _PrimitiveView {
    let name: String

    /// `Image(systemName:)` — SF Symbol stub.
    public init(systemName: String) {
        self.name = systemName
    }

    /// `Image(_:)` — named image.
    public init(_ name: String) {
        self.name = name
    }

    /// `Image(nsImage:)` — creates an image from an NSImage. Stub: uses empty name.
    public init(nsImage: NSImage) {
        self.name = ""
    }

    public var _nodeRepresentation: ViewNode {
        .image(name: name, width: nil, height: nil)
    }

    /// Image rendering scale.
    public enum Scale { case small, medium, large }

    /// Image rendering mode.
    public func renderingMode(_ mode: TemplateRenderingMode?) -> Image { self }

    /// Image template rendering mode.
    public enum TemplateRenderingMode { case original, template }

    /// Returns a resizable version of this image.
    public func resizable(capInsets: EdgeInsets = EdgeInsets(), resizingMode: ResizingMode = .stretch) -> Image { self }

    /// Image resizing mode.
    public enum ResizingMode { case tile, stretch }

    /// Returns an interpolated version of this image.
    public func interpolation(_ interpolation: Interpolation) -> Image { self }

    /// Image interpolation.
    public enum Interpolation { case none, low, medium, high }

    /// Returns an antialiased version of this image.
    public func antialiased(_ isAntialiased: Bool) -> Image { self }

    /// `.symbolRenderingMode(_:)` — no-op on Clone.
    public func symbolRenderingMode(_ mode: SymbolRenderingMode?) -> Image { self }
}
