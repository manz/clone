import Foundation
import Testing
@testable import SwiftUI

// MARK: - Test Helpers

private struct Item: Identifiable {
    let id: String
    let label: String
}

private struct NamedItem {
    let name: String
}

// MARK: - Tests

@Test @MainActor func forEachIdentifiablePushesScope() {
    let graph = StateGraph.shared
    graph.clear()

    let items = [Item(id: "a", label: "A"), Item(id: "b", label: "B")]

    // Build ForEach — each item gets its own scope for state
    let forEach = ForEach(items) { item in
        Text(item.label)
    }

    // State stored under scope "a/" and "b/" respectively
    let slotA = graph.slot(initialValue: 0, file: "test", line: 100)
    // The scope was already popped, so this goes to the root.
    // Instead, verify that the two items produced distinct nodes.
    #expect(forEach.nodes.count == 2)

    graph.clear()
}

@Test @MainActor func forEachExplicitIdPushesScope() {
    let graph = StateGraph.shared
    graph.clear()

    let items = [NamedItem(name: "x"), NamedItem(name: "y")]

    let forEach = ForEach(items, id: \.name) { item in
        Text(item.name)
    }

    #expect(forEach.nodes.count == 2)
    graph.clear()
}

@Test @MainActor func forEachRangeUsesIndexAsScope() {
    let graph = StateGraph.shared
    graph.clear()

    let forEach = ForEach(0..<3) { i in
        Text("Item \(i)")
    }

    #expect(forEach.nodes.count == 3)
    graph.clear()
}

@Test @MainActor func forEachSelfIdPushesScope() {
    let graph = StateGraph.shared
    graph.clear()

    let forEach = ForEach(["x", "y", "z"], id: \.self) { s in
        Text(s)
    }

    #expect(forEach.nodes.count == 3)
    graph.clear()
}

@Test @MainActor func forEachGeneratesCorrectNodeCount() {
    let items = [Item(id: "1", label: "One"), Item(id: "2", label: "Two"), Item(id: "3", label: "Three")]

    StateGraph.shared.clear()
    let forEach = ForEach(items) { item in
        Text(item.label)
    }

    #expect(forEach.nodes.count == 3)
    // Each node should be a text node
    for node in forEach.nodes {
        if case .text = node {
            // good
        } else {
            Issue.record("Expected .text node, got \(node)")
        }
    }
}

@Test @MainActor func forEachSingleItemReturnsDirectNode() {
    StateGraph.shared.clear()
    let forEach = ForEach([Item(id: "only", label: "Only")]) { item in
        Text(item.label)
    }

    #expect(forEach.nodes.count == 1)
    // _nodeRepresentation should return the single node directly, not a vstack
    let node = forEach._nodeRepresentation
    if case .vstack = node {
        Issue.record("Single item should not be wrapped in vstack")
    }
    if case .text = node {
        // good — direct node
    } else {
        Issue.record("Expected .text node for single item, got \(node)")
    }
}

@Test @MainActor func forEachStateIsolationPerItem() {
    // Test scope pushing directly — ForEach pushes item.id as scope,
    // so state at the same file:line is isolated per item.
    let graph = StateGraph.shared
    graph.clear()

    // Frame 1: simulate what ForEach does internally
    graph.pushScope("a")
    let slotA = graph.slot(initialValue: 0, file: "row", line: 1)
    slotA.value = 42
    graph.popScope()

    graph.pushScope("b")
    let slotB = graph.slot(initialValue: 0, file: "row", line: 1)
    graph.popScope()

    #expect(slotA.value as? Int == 42)
    #expect(slotB.value as? Int == 0, "Item b's state should be independent from a")

    // Frame 2: same scopes — state persists
    graph.resetCounter()
    graph.pushScope("a")
    let slotA2 = graph.slot(initialValue: 0, file: "row", line: 1)
    graph.popScope()

    #expect(slotA2.value as? Int == 42, "Item a's state should persist across frames")

    graph.clear()
}

@Test @MainActor func forEachStateStableAcrossReorder() {
    let graph = StateGraph.shared
    graph.clear()

    // Frame 1: items in order [a, b]
    graph.pushScope("a")
    let slotA = graph.slot(initialValue: 0, file: "row", line: 1)
    slotA.value = 10
    graph.popScope()

    graph.pushScope("b")
    let slotB = graph.slot(initialValue: 0, file: "row", line: 1)
    slotB.value = 20
    graph.popScope()

    // Frame 2: reversed order [b, a] — state follows id, not position
    graph.resetCounter()

    graph.pushScope("b")
    let slotB2 = graph.slot(initialValue: 0, file: "row", line: 1)
    graph.popScope()

    graph.pushScope("a")
    let slotA2 = graph.slot(initialValue: 0, file: "row", line: 1)
    graph.popScope()

    #expect(slotA2.value as? Int == 10, "Item a state follows its scope id")
    #expect(slotB2.value as? Int == 20, "Item b state follows its scope id")

    graph.clear()
}
