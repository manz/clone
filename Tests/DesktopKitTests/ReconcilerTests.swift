import Testing
@testable import DesktopKit

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
        .text("A", fontSize: 14, color: .text),
    ])
    let new = ViewNode.vstack(alignment: .center, spacing: 8, children: [
        .text("A", fontSize: 14, color: .text),
        .text("B", fontSize: 14, color: .text),
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
        .text("A", fontSize: 14, color: .text),
        .text("B", fontSize: 14, color: .text),
    ])
    let new = ViewNode.vstack(alignment: .center, spacing: 8, children: [
        .text("A", fontSize: 14, color: .text),
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
        .text("A", fontSize: 14, color: .text),
        .hstack(alignment: .center, spacing: 4, children: [
            .text("B", fontSize: 14, color: .text),
            .text("C", fontSize: 14, color: .text),
        ]),
    ])
    let new = ViewNode.vstack(alignment: .center, spacing: 8, children: [
        .text("A", fontSize: 14, color: .text),
        .hstack(alignment: .center, spacing: 4, children: [
            .text("B", fontSize: 14, color: .text),
            .text("D", fontSize: 14, color: .text), // Changed C -> D
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
    let children: [ViewNode] = [.text("A", fontSize: 14, color: .text)]
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
        .rect(width: nil, height: nil, fill: .base),
        .vstack(alignment: .center, spacing: 8, children: [
            .text("Title", fontSize: 24, color: .white),
            .roundedRect(width: 200, height: 100, radius: 12, fill: .surface),
        ]),
    ])
    let patches = Reconciler.diff(old: tree, new: tree)
    #expect(patches.isEmpty)
}
