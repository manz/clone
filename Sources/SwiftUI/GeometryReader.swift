import Foundation

/// Geometry information available to GeometryReader children.
public struct GeometryProxy: Sendable {
    /// The size proposed by the parent.
    public let size: CGSize

    /// The frame in the global coordinate space.
    public let frame: LayoutFrame

    public init(size: CGSize, frame: LayoutFrame) {
        self.size = size
        self.frame = frame
    }

    public var width: CGFloat { size.width }
    public var height: CGFloat { size.height }
}

/// Registry that holds GeometryReader closures by ID.
/// During layout, when a `.geometryReader(id:)` node is encountered,
/// the resolver is called to produce the child ViewNode.
public final class GeometryReaderRegistry: @unchecked Sendable {
    public static let shared = GeometryReaderRegistry()

    private var closures: [UInt64: (GeometryProxy) -> ViewNode] = [:]
    private var nextId: UInt64 = 0

    private init() {}

    /// Register a closure and return its ID.
    @discardableResult
    public func register(_ closure: @escaping (GeometryProxy) -> ViewNode) -> UInt64 {
        let id = nextId
        nextId += 1
        closures[id] = closure
        return id
    }

    /// Resolve a GeometryReader by calling its closure with the proxy.
    public func resolve(id: UInt64, proxy: GeometryProxy) -> ViewNode {
        guard let closure = closures[id] else { return .empty }
        return closure(proxy)
    }

    /// Clear all registered closures (call between frames).
    public func clear() {
        closures.removeAll()
        nextId = 0
    }
}

/// `GeometryReader { proxy in ... }` — SwiftUI-style constructor.
/// Registers the closure and returns a `.geometryReader(id:)` ViewNode.
public struct GeometryReader<Content: View>: _PrimitiveView {
    let child: ViewNode

    public init(@ViewBuilder content: @escaping (GeometryProxy) -> Content) {
        let id = GeometryReaderRegistry.shared.register { proxy in
            _resolve(content(proxy))
        }
        self.child = .geometryReader(id: id)
    }

    /// Convenience init with non-ViewBuilder closure for backwards compatibility.
    public init(_ content: @escaping (GeometryProxy) -> Content) {
        let id = GeometryReaderRegistry.shared.register { proxy in
            _resolve(content(proxy))
        }
        self.child = .geometryReader(id: id)
    }

    public var _nodeRepresentation: ViewNode {
        child
    }
}
