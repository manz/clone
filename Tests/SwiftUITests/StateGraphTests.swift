import Testing
import Foundation
@testable import SwiftUI

@Test @MainActor func stateGraphPersistsAcrossResets() {
    StateGraph.shared.clear()

    let slot1 = StateGraph.shared.slot(initialValue: 42, file: "test", line: 1)
    #expect(slot1.value as! Int == 42)

    slot1.value = 99

    // Simulate new frame — reset call counts so same file+line maps to same slot
    StateGraph.shared.resetCounter()

    let slot2 = StateGraph.shared.slot(initialValue: 42, file: "test", line: 1)
    #expect(slot2.value as! Int == 99)  // Persisted, not reset to 42
}

@Test @MainActor func stateGraphDifferentLocations() {
    StateGraph.shared.clear()

    let s1 = StateGraph.shared.slot(initialValue: "hello", file: "test", line: 10)
    let s2 = StateGraph.shared.slot(initialValue: 0, file: "test", line: 20)

    s1.value = "world"
    s2.value = 42

    // Simulate new frame
    StateGraph.shared.resetCounter()

    let r1 = StateGraph.shared.slot(initialValue: "hello", file: "test", line: 10)
    let r2 = StateGraph.shared.slot(initialValue: 0, file: "test", line: 20)

    #expect(r1.value as! String == "world")
    #expect(r2.value as! Int == 42)
}

@Test @MainActor func statePersistsValueAcrossFrames() {
    StateGraph.shared.clear()

    let state1 = State(wrappedValue: [1, 2, 3], file: "TestView.swift", line: 5)
    #expect(state1.wrappedValue == [1, 2, 3])
    state1.wrappedValue = [4, 5, 6]

    // Simulate new frame
    StateGraph.shared.resetCounter()

    let state2 = State(wrappedValue: [1, 2, 3], file: "TestView.swift", line: 5)
    #expect(state2.wrappedValue == [4, 5, 6])  // Persisted!
}

@Test @MainActor func stateBindingPersists() {
    StateGraph.shared.clear()

    let state = State(wrappedValue: "initial", file: "TestView.swift", line: 10)
    let binding = state.projectedValue
    binding.wrappedValue = "modified"

    // Simulate new frame
    StateGraph.shared.resetCounter()

    let state2 = State(wrappedValue: "initial", file: "TestView.swift", line: 10)
    #expect(state2.wrappedValue == "modified")
}

@Test @MainActor func stateGraphForEachDistinctSlots() {
    StateGraph.shared.clear()

    // Simulate ForEach: same file:line called 3 times in one frame
    let slot0 = StateGraph.shared.slot(initialValue: "a", file: "ForEachView.swift", line: 5)
    let slot1 = StateGraph.shared.slot(initialValue: "b", file: "ForEachView.swift", line: 5)
    let slot2 = StateGraph.shared.slot(initialValue: "c", file: "ForEachView.swift", line: 5)

    // Each should be distinct
    #expect(slot0.value as! String == "a")
    #expect(slot1.value as! String == "b")
    #expect(slot2.value as! String == "c")

    slot0.value = "A"
    slot1.value = "B"

    // Simulate new frame
    StateGraph.shared.resetCounter()

    // Same sequence of calls maps back to same slots
    let r0 = StateGraph.shared.slot(initialValue: "a", file: "ForEachView.swift", line: 5)
    let r1 = StateGraph.shared.slot(initialValue: "b", file: "ForEachView.swift", line: 5)
    let r2 = StateGraph.shared.slot(initialValue: "c", file: "ForEachView.swift", line: 5)

    #expect(r0.value as! String == "A")  // Persisted
    #expect(r1.value as! String == "B")  // Persisted
    #expect(r2.value as! String == "c")  // Unchanged
}

@Test @MainActor func stateGraphScopeStableAcrossReorder() {
    StateGraph.shared.clear()

    // Frame 1: items in order [A, B, C]
    for id in ["A", "B", "C"] {
        StateGraph.shared.pushScope(id)
        let slot = StateGraph.shared.slot(initialValue: "init-\(id)", file: "Row.swift", line: 3)
        slot.value = "modified-\(id)"
        StateGraph.shared.popScope()
    }

    // Frame 2: items REORDERED to [C, A, B]
    StateGraph.shared.resetCounter()

    for id in ["C", "A", "B"] {
        StateGraph.shared.pushScope(id)
        let slot = StateGraph.shared.slot(initialValue: "init-\(id)", file: "Row.swift", line: 3)
        // State should persist per-id, not per-position
        #expect(slot.value as! String == "modified-\(id)")
        StateGraph.shared.popScope()
    }
}

@Test @MainActor func stateGraphScopeStableAcrossInsertionDeletion() {
    StateGraph.shared.clear()

    // Frame 1: items [A, B]
    StateGraph.shared.pushScope("A")
    let slotA = StateGraph.shared.slot(initialValue: 0, file: "Row.swift", line: 5)
    slotA.value = 100
    StateGraph.shared.popScope()

    StateGraph.shared.pushScope("B")
    let slotB = StateGraph.shared.slot(initialValue: 0, file: "Row.swift", line: 5)
    slotB.value = 200
    StateGraph.shared.popScope()

    // Frame 2: item A deleted, C inserted → [B, C]
    StateGraph.shared.resetCounter()

    StateGraph.shared.pushScope("B")
    let slotB2 = StateGraph.shared.slot(initialValue: 0, file: "Row.swift", line: 5)
    #expect(slotB2.value as! Int == 200)  // B's state survived
    StateGraph.shared.popScope()

    StateGraph.shared.pushScope("C")
    let slotC = StateGraph.shared.slot(initialValue: 0, file: "Row.swift", line: 5)
    #expect(slotC.value as! Int == 0)  // C is new, gets initial value
    StateGraph.shared.popScope()
}
