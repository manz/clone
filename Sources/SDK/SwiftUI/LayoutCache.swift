import Foundation

/// Caches LayoutNode results across frames.
/// If a ViewNode subtree is identical to the previous frame's AND at the same position,
/// the cached LayoutNode is reused — skipping the entire layout subtree.
///
/// Double-buffered: call `swapFrames()` at each frame start.
public final class LayoutCache: @unchecked Sendable {
    public static let shared = LayoutCache()

    private struct Entry {
        let node: ViewNode
        let frame: LayoutFrame
        let result: LayoutNode
    }

    private var previous: [Entry] = []
    private var current: [Entry] = []

    public private(set) var hitsThisFrame: Int = 0
    public private(set) var missesThisFrame: Int = 0

    private init() {}

    public func swapFrames() {
        previous = current
        current = []
        current.reserveCapacity(previous.count)
        hitsThisFrame = 0
        missesThisFrame = 0
    }

    public func lookup(_ node: ViewNode, frame: LayoutFrame) -> LayoutNode? {
        // Skip cache for nodes whose layout depends on external state
        // (not encoded in the ViewNode itself)
        switch node {
        case .geometryReader,   // layout depends on parent frame callback
             .lazyList,          // pulls rows from LazyRowRegistry
             .lazyStack,         // virtualized based on viewport
             .textField,         // cursor/focus state from TextFieldRegistry
             .scrollView,        // scroll offset from ScrollRegistry
             .list:              // scroll offset from ScrollRegistry
            missesThisFrame += 1
            return nil
        default:
            break
        }

        for entry in previous {
            if entry.frame == frame && entry.node == node {
                current.append(Entry(node: node, frame: frame, result: entry.result))
                hitsThisFrame += 1
                return entry.result
            }
        }
        missesThisFrame += 1
        return nil
    }

    public func store(_ node: ViewNode, frame: LayoutFrame, result: LayoutNode) {
        current.append(Entry(node: node, frame: frame, result: result))
    }

    public func clear() {
        previous.removeAll()
        current.removeAll()
        hitsThisFrame = 0
        missesThisFrame = 0
    }
}
