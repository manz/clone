import Foundation

/// Patch operations produced by diffing two ViewNode trees.
public enum Patch: Equatable, Sendable {
    /// Replace the node at the given path with a new node.
    case replace(path: [Int], node: ViewNode)
    /// Insert a child at the given path and index.
    case insert(path: [Int], index: Int, node: ViewNode)
    /// Remove a child at the given path and index.
    case remove(path: [Int], index: Int)
    /// Update a property (captured as full node replacement for simplicity).
    case update(path: [Int], node: ViewNode)
}

/// Diffs two ViewNode trees and produces a minimal set of patches.
public enum Reconciler {

    public static func diff(old: ViewNode, new: ViewNode) -> [Patch] {
        var patches: [Patch] = []
        diffNode(old: old, new: new, path: [], patches: &patches)
        return patches
    }

    private static func diffNode(
        old: ViewNode,
        new: ViewNode,
        path: [Int],
        patches: inout [Patch]
    ) {
        // If structurally equal, no patches needed
        if old == new { return }

        // If different node types, replace entirely
        guard sameVariant(old, new) else {
            patches.append(.replace(path: path, node: new))
            return
        }

        // Same variant — diff children
        switch (old, new) {
        case (.vstack(let oAlign, let oSpacing, let oChildren),
              .vstack(let nAlign, let nSpacing, let nChildren)):
            if oAlign != nAlign || oSpacing != nSpacing {
                patches.append(.update(path: path, node: new))
            }
            diffChildren(old: oChildren, new: nChildren, path: path, patches: &patches)

        case (.hstack(let oAlign, let oSpacing, let oChildren),
              .hstack(let nAlign, let nSpacing, let nChildren)):
            if oAlign != nAlign || oSpacing != nSpacing {
                patches.append(.update(path: path, node: new))
            }
            diffChildren(old: oChildren, new: nChildren, path: path, patches: &patches)

        case (.zstack(let oChildren), .zstack(let nChildren)):
            diffChildren(old: oChildren, new: nChildren, path: path, patches: &patches)

        case (.padding(let oInsets, let oChild), .padding(let nInsets, let nChild)):
            if oInsets != nInsets {
                patches.append(.update(path: path, node: new))
            }
            diffNode(old: oChild, new: nChild, path: path + [0], patches: &patches)

        case (.frame(let oW, let oH, let oChild), .frame(let nW, let nH, let nChild)):
            if oW != nW || oH != nH {
                patches.append(.update(path: path, node: new))
            }
            diffNode(old: oChild, new: nChild, path: path + [0], patches: &patches)

        case (.opacity(let oVal, let oChild), .opacity(let nVal, let nChild)):
            if oVal != nVal {
                patches.append(.update(path: path, node: new))
            }
            diffNode(old: oChild, new: nChild, path: path + [0], patches: &patches)

        case (.onTap(let oId, let oChild), .onTap(let nId, let nChild)):
            if oId != nId {
                patches.append(.update(path: path, node: new))
            }
            diffNode(old: oChild, new: nChild, path: path + [0], patches: &patches)

        default:
            // Leaf nodes that are same variant but different values
            patches.append(.update(path: path, node: new))
        }
    }

    private static func diffChildren(
        old: [ViewNode],
        new: [ViewNode],
        path: [Int],
        patches: inout [Patch]
    ) {
        let minCount = min(old.count, new.count)

        // Diff matching children
        for i in 0..<minCount {
            diffNode(old: old[i], new: new[i], path: path + [i], patches: &patches)
        }

        // Handle added children
        for i in minCount..<new.count {
            patches.append(.insert(path: path, index: i, node: new[i]))
        }

        // Handle removed children
        for i in minCount..<old.count {
            patches.append(.remove(path: path, index: i))
        }
    }

    /// Check if two ViewNodes are the same variant (ignoring associated values).
    private static func sameVariant(_ a: ViewNode, _ b: ViewNode) -> Bool {
        switch (a, b) {
        case (.empty, .empty): return true
        case (.text, .text): return true
        case (.rect, .rect): return true
        case (.roundedRect, .roundedRect): return true
        case (.blur, .blur): return true
        case (.spacer, .spacer): return true
        case (.vstack, .vstack): return true
        case (.hstack, .hstack): return true
        case (.zstack, .zstack): return true
        case (.padding, .padding): return true
        case (.frame, .frame): return true
        case (.opacity, .opacity): return true
        case (.shadow, .shadow): return true
        case (.onTap, .onTap): return true
        case (.geometryReader, .geometryReader): return true
        case (.scrollView, .scrollView): return true
        case (.list, .list): return true
        case (.image, .image): return true
        case (.toggle, .toggle): return true
        case (.slider, .slider): return true
        case (.picker, .picker): return true
        case (.textField, .textField): return true
        case (.navigationStack, .navigationStack): return true
        default: return false
        }
    }
}
