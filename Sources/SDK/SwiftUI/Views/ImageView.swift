import Foundation
import CloneRender

/// A view that displays an image. Matches Apple's SwiftUI `Image` struct.
public struct Image: _PrimitiveView {
    let name: String
    var fontSize: CGFloat?

    // Raster image data (decoded RGBA)
    var textureId: UInt64?
    var imageWidth: UInt32?
    var imageHeight: UInt32?
    var rgbaData: [UInt8]?

    /// `Image(systemName:)` — SF Symbol / Phosphor icon.
    public init(systemName: String) {
        self.name = systemName
    }

    /// `Image(_:)` — named image (icon lookup).
    public init(_ name: String) {
        self.name = name
    }

    /// `Image(nsImage:)` — creates an image from an NSImage (stub — no rendering).
    public init(nsImage: NSImage) {
        self.name = ""
    }

    /// Load a raster image from a file path.
    public init(contentsOfFile path: String) {
        self.name = ""
        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            Self.loadRaster(from: data, into: &self)
        }
    }

    private static func loadRaster(from fileData: Data, into image: inout Image) {
        do {
            let decoded = try decodeImage(data: fileData)
            image.textureId = UInt64(fileData.hashValue & 0x7FFFFFFFFFFFFFFF)
            image.imageWidth = decoded.width
            image.imageHeight = decoded.height
            image.rgbaData = [UInt8](decoded.rgbaData)
        } catch {
            fputs("[Image] Failed to decode image: \(error)\n", stderr)
        }
    }

    public var _nodeRepresentation: ViewNode {
        if let textureId, let imgW = imageWidth, let imgH = imageHeight {
            // Register texture once (ImagePipeline skips if already registered).
            // The ViewNode only carries the ID + dimensions — no pixel data per frame.
            if let rgba = rgbaData, !ImageTextureCache.shared.isRegistered(textureId) {
                ImageTextureCache.shared.register(textureId: textureId, width: imgW, height: imgH, rgbaData: rgba)
            }
            return .rasterImage(textureId: textureId, imageWidth: imgW, imageHeight: imgH, rgbaData: [])
        }
        return .image(name: name, width: fontSize, height: fontSize)
    }

    /// `.font()` on Image sets the icon size (like SF Symbols).
    public func font(_ font: Font) -> Image {
        var copy = self
        copy.fontSize = font.size
        return copy
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
