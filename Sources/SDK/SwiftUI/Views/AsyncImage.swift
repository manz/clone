import Foundation
import CloneRender

/// The current phase of an asynchronous image loading operation.
public enum AsyncImagePhase: Sendable {
    case empty
    case success(Image)
    case failure(Error)

    public var image: Image? {
        if case .success(let img) = self { return img }
        return nil
    }

    public var error: Error? {
        if case .failure(let err) = self { return err }
        return nil
    }
}

/// Shared cache for AsyncImage — keyed by URL string.
/// Images are fetched once and cached for the app's lifetime.
final class AsyncImageCache: @unchecked Sendable {
    static let shared = AsyncImageCache()
    private init() {}

    private var cache: [String: AsyncImagePhase] = [:]
    private var inFlight: Set<String> = []

    func phase(for url: URL) -> AsyncImagePhase {
        cache[url.absoluteString] ?? .empty
    }

    func startFetch(url: URL) {
        let key = url.absoluteString
        guard cache[key] == nil, !inFlight.contains(key) else { return }
        inFlight.insert(key)

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self else { return }
            if let data, let decoded = try? decodeImage(data: data) {
                let image = Image._fromDecodedRGBA(
                    textureId: UInt64(key.hashValue & 0x7FFFFFFFFFFFFFFF),
                    width: decoded.width,
                    height: decoded.height,
                    rgbaData: [UInt8](decoded.rgbaData)
                )
                self.cache[key] = .success(image)
            } else if let error {
                self.cache[key] = .failure(error)
            } else {
                self.cache[key] = .failure(NSError(domain: "AsyncImage", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode image"]))
            }
            self.inFlight.remove(key)
            // Trigger re-render so the image appears
            DispatchQueue.main.async {
                StateGraph.shared.invalidate()
            }
        }.resume()
    }
}

/// A view that asynchronously loads and displays an image from a URL.
public struct AsyncImage<Content: View>: _PrimitiveView {
    let url: URL?
    let scale: CGFloat
    let makeContent: (AsyncImagePhase) -> ViewNode

    /// Creates an async image with a URL. Shows a gray placeholder while loading.
    public init(url: URL?, scale: CGFloat = 1) where Content == Image {
        self.url = url
        self.scale = scale
        self.makeContent = { phase in
            if case .success(let img) = phase {
                return img._nodeRepresentation
            }
            return ViewNode.rect(width: nil, height: nil, fill: Color(white: 0.85))
        }
    }

    /// Creates an async image with a custom content/placeholder builder.
    public init<I: View, P: View>(
        url: URL?,
        scale: CGFloat = 1,
        @ViewBuilder content: @escaping (Image) -> I,
        @ViewBuilder placeholder: () -> P
    ) where Content == _ConditionalContent<I, P> {
        self.url = url
        self.scale = scale
        let placeholderNode = _resolve(placeholder())
        self.makeContent = { phase in
            if case .success(let img) = phase {
                return _resolve(content(img))
            }
            return placeholderNode
        }
    }

    /// Creates an async image with a phase-based builder.
    public init(
        url: URL?,
        scale: CGFloat = 1,
        transaction: Any? = nil,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.scale = scale
        self.makeContent = { phase in
            _resolve(content(phase))
        }
    }

    public var _nodeRepresentation: ViewNode {
        guard let url else { return makeContent(.empty) }

        // Start fetch if not cached
        AsyncImageCache.shared.startFetch(url: url)

        // Return current phase (empty on first frame, success on subsequent)
        let phase = AsyncImageCache.shared.phase(for: url)
        return makeContent(phase)
    }
}

// _ConditionalContent is defined in ViewBuilder.swift

// MARK: - Image helper for creating from decoded RGBA

extension Image {
    /// Create an Image from pre-decoded RGBA data.
    public static func _fromDecodedRGBA(textureId: UInt64, width: UInt32, height: UInt32, rgbaData: [UInt8]) -> Image {
        var img = Image("")
        img.textureId = textureId
        img.imageWidth = width
        img.imageHeight = height
        img.rgbaData = rgbaData
        return img
    }
}
