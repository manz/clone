import Testing
@testable import SwiftUI

@Test func noChangeProducesNoPatches() {
    let tree = ViewNode.text("Hello", fontSize: 16, color: .white)
    let patches = Reconciler.diff(old: tree, new: tree)
    #expect(patches.isEmpty)
}

@Test func differentNodeTypeProducesReplace() {
    let old = ViewNode.text("Hello", fontSize: 16, color: .white)
    let new = ViewNode.rect(width: 100, height: 50, fill: .white)
    let patches = Reconciler.diff(old: old, new: new)
    #expect(patches.count == 1)
    if case .replace(let path, _) = patches[0] {
        #expect(path.isEmpty)
    } else {
        Issue.record("Expected replace patch")
    }
}

@Test func textContentChangeProducesUpdate() {
    let old = ViewNode.text("Hello", fontSize: 16, color: .white)
    let new = ViewNode.text("World", fontSize: 16, color: .white)
    let patches = Reconciler.diff(old: old, new: new)
    #expect(patches.count == 1)
    if case .update(let path, _) = patches[0] {
        #expect(path.isEmpty)
    } else {
        Issue.record("Expected update patch")
    }
}

@Test func childAdditionProducesInsert() {
    let old = ViewNode.vstack(alignment: .center, spacing: 8, children: [
        .text("A", fontSize: 14, color: .primary),
    ])
    let new = ViewNode.vstack(alignment: .center, spacing: 8, children: [
        .text("A", fontSize: 14, color: .primary),
        .text("B", fontSize: 14, color: .primary),
    ])
    let patches = Reconciler.diff(old: old, new: new)
    #expect(patches.count == 1)
    if case .insert(let path, let index, _) = patches[0] {
        #expect(path.isEmpty)
        #expect(index == 1)
    } else {
        Issue.record("Expected insert patch")
    }
}

@Test func childRemovalProducesRemove() {
    let old = ViewNode.vstack(alignment: .center, spacing: 8, children: [
        .text("A", fontSize: 14, color: .primary),
        .text("B", fontSize: 14, color: .primary),
    ])
    let new = ViewNode.vstack(alignment: .center, spacing: 8, children: [
        .text("A", fontSize: 14, color: .primary),
    ])
    let patches = Reconciler.diff(old: old, new: new)
    #expect(patches.count == 1)
    if case .remove(let path, let index) = patches[0] {
        #expect(path.isEmpty)
        #expect(index == 1)
    } else {
        Issue.record("Expected remove patch")
    }
}

@Test func nestedChildChangeProducesCorrectPath() {
    let old = ViewNode.vstack(alignment: .center, spacing: 8, children: [
        .text("A", fontSize: 14, color: .primary),
        .hstack(alignment: .center, spacing: 4, children: [
            .text("B", fontSize: 14, color: .primary),
            .text("C", fontSize: 14, color: .primary),
        ]),
    ])
    let new = ViewNode.vstack(alignment: .center, spacing: 8, children: [
        .text("A", fontSize: 14, color: .primary),
        .hstack(alignment: .center, spacing: 4, children: [
            .text("B", fontSize: 14, color: .primary),
            .text("D", fontSize: 14, color: .primary), // Changed C -> D
        ]),
    ])
    let patches = Reconciler.diff(old: old, new: new)
    #expect(patches.count == 1)
    if case .update(let path, _) = patches[0] {
        // Path should be [1, 1] — second child of vstack, second child of hstack
        #expect(path == [1, 1])
    } else {
        Issue.record("Expected update patch at [1, 1]")
    }
}

@Test func opacityChangeProducesUpdate() {
    let child = ViewNode.rect(width: 100, height: 50, fill: .white)
    let old = ViewNode.opacity(0.5, child: child)
    let new = ViewNode.opacity(0.8, child: child)
    let patches = Reconciler.diff(old: old, new: new)
    #expect(patches.count == 1)
    if case .update(_, _) = patches[0] {
        // OK
    } else {
        Issue.record("Expected update patch for opacity")
    }
}

@Test func spacingChangeProducesUpdate() {
    let children: [ViewNode] = [.text("A", fontSize: 14, color: .primary)]
    let old = ViewNode.vstack(alignment: .center, spacing: 8, children: children)
    let new = ViewNode.vstack(alignment: .center, spacing: 16, children: children)
    let patches = Reconciler.diff(old: old, new: new)
    #expect(patches.count == 1)
    if case .update(let path, _) = patches[0] {
        #expect(path.isEmpty)
    } else {
        Issue.record("Expected update for spacing change")
    }
}

@Test func complexTreeNoChangeIsEmpty() {
    let tree = ViewNode.zstack(children: [
        .rect(width: nil, height: nil, fill: .gray),
        .vstack(alignment: .center, spacing: 8, children: [
            .text("Title", fontSize: 24, color: .white),
            .roundedRect(width: 200, height: 100, radius: 12, fill: .white),
        ]),
    ])
    let patches = Reconciler.diff(old: tree, new: tree)
    #expect(patches.isEmpty)
}

// MARK: - Deep nesting

@Test func deepNestedSingleChange() {
    let innerOld = ViewNode.text("Old", fontSize: 14, color: .primary)
    let innerNew = ViewNode.text("New", fontSize: 14, color: .primary)

    let old = ViewNode.vstack(alignment: .leading, spacing: 0, children: [
        .padding(EdgeInsets(), child:
            .hstack(alignment: .center, spacing: 0, children: [innerOld])
        )
    ])
    let new = ViewNode.vstack(alignment: .leading, spacing: 0, children: [
        .padding(EdgeInsets(), child:
            .hstack(alignment: .center, spacing: 0, children: [innerNew])
        )
    ])
    let patches = Reconciler.diff(old: old, new: new)
    #expect(patches.count == 1)
    if case .update(let path, _) = patches[0] {
        #expect(path == [0, 0, 0])
    }
}

// MARK: - Mixed changes: some children changed, some not

@Test func mixedChildrenChanges() {
    let old = ViewNode.vstack(alignment: .leading, spacing: 0, children: [
        .text("Changed", fontSize: 14, color: .primary),
        .text("Same", fontSize: 14, color: .primary),
        .text("Also Changed", fontSize: 14, color: .primary),
    ])
    let new = ViewNode.vstack(alignment: .leading, spacing: 0, children: [
        .text("MODIFIED", fontSize: 14, color: .primary),
        .text("Same", fontSize: 14, color: .primary),
        .text("ALSO MODIFIED", fontSize: 14, color: .primary),
    ])
    let patches = Reconciler.diff(old: old, new: new)
    #expect(patches.count == 2) // first and third changed, middle untouched
}

// MARK: - Wrapper node child changes

@Test func clippedChildChange() {
    let old = ViewNode.clipped(radius: 8, child: .text("A", fontSize: 14, color: .primary))
    let new = ViewNode.clipped(radius: 8, child: .text("B", fontSize: 14, color: .primary))
    let patches = Reconciler.diff(old: old, new: new)
    #expect(patches.count == 1)
}

@Test func taggedChildChange() {
    let tag = SendableHashable("t")
    let old = ViewNode.tagged(tag: tag, child: .text("A", fontSize: 14, color: .primary))
    let new = ViewNode.tagged(tag: tag, child: .text("B", fontSize: 14, color: .primary))
    let patches = Reconciler.diff(old: old, new: new)
    #expect(patches.count == 1)
}

@Test func lineLimitChildChange() {
    let old = ViewNode.lineLimit(limit: 1, child: .text("Short", fontSize: 14, color: .primary))
    let new = ViewNode.lineLimit(limit: 1, child: .text("Long text here", fontSize: 14, color: .primary))
    let patches = Reconciler.diff(old: old, new: new)
    #expect(patches.count == 1)
}

// MARK: - ScrollView

@Test func scrollViewChildAdded() {
    let old = ViewNode.scrollView(axes: .vertical, children: [
        .text("A", fontSize: 14, color: .primary),
    ], key: "s1")
    let new = ViewNode.scrollView(axes: .vertical, children: [
        .text("A", fontSize: 14, color: .primary),
        .text("B", fontSize: 14, color: .primary),
    ], key: "s1")
    let patches = Reconciler.diff(old: old, new: new)
    #expect(patches.count == 1)
    if case .insert(_, let idx, _) = patches[0] {
        #expect(idx == 1)
    }
}

// MARK: - Grid

@Test func gridChildChange() {
    let cols = [GridColumnSpec(.flexible(min: 0, max: .infinity))]
    let old = ViewNode.grid(columns: cols, spacing: 8, children: [
        .text("A", fontSize: 14, color: .primary),
    ])
    let new = ViewNode.grid(columns: cols, spacing: 8, children: [
        .text("B", fontSize: 14, color: .primary),
    ])
    let patches = Reconciler.diff(old: old, new: new)
    #expect(patches.count == 1)
}

// MARK: - Performance: large tree

@Test func largeTreeSingleChange() {
    let children = (0..<500).map { ViewNode.text("Item \($0)", fontSize: 14, color: .primary) }
    let old = ViewNode.vstack(alignment: .leading, spacing: 0, children: children)

    var newChildren = children
    newChildren[250] = .text("CHANGED", fontSize: 14, color: .red)
    let new = ViewNode.vstack(alignment: .leading, spacing: 0, children: newChildren)

    let patches = Reconciler.diff(old: old, new: new)
    #expect(patches.count == 1)
    if case .update(let path, _) = patches[0] {
        #expect(path == [250])
    }
}

@Test func identicalLargeTreeNoPatches() {
    let children = (0..<1000).map { ViewNode.text("Item \($0)", fontSize: 14, color: .primary) }
    let tree = ViewNode.vstack(alignment: .leading, spacing: 0, children: children)
    let patches = Reconciler.diff(old: tree, new: tree)
    #expect(patches.isEmpty)
}

// MARK: - Empty transitions

@Test func emptyToNonEmpty() {
    let patches = Reconciler.diff(old: .empty, new: .text("Hi", fontSize: 14, color: .primary))
    #expect(patches.count == 1)
    if case .replace = patches[0] {} else { Issue.record("Expected replace") }
}

@Test func nonEmptyToEmpty() {
    let patches = Reconciler.diff(old: .text("Hi", fontSize: 14, color: .primary), new: .empty)
    #expect(patches.count == 1)
    if case .replace = patches[0] {} else { Issue.record("Expected replace") }
}
