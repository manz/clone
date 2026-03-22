import Testing
import Foundation
@testable import SwiftUI

@Test @MainActor func stateGraphPersistsAcrossResets() {
    StateGraph.shared.clear()

    // First frame: create state with initial value
    let slot1 = StateGraph.shared.slot(initialValue: 42)
    #expect(slot1.value as! Int == 42)

    // Mutate
    slot1.value = 99

    // Reset counter (simulates next frame)
    StateGraph.shared.resetCounter()

    // Second frame: same position gets same slot
    let slot2 = StateGraph.shared.slot(initialValue: 42)
    #expect(slot2.value as! Int == 99)  // Persisted, not reset to 42
}

@Test @MainActor func stateGraphMultipleSlots() {
    StateGraph.shared.clear()

    let s1 = StateGraph.shared.slot(initialValue: "hello")
    let s2 = StateGraph.shared.slot(initialValue: 0)
    let s3 = StateGraph.shared.slot(initialValue: true)

    s1.value = "world"
    s2.value = 42
    s3.value = false

    StateGraph.shared.resetCounter()

    let r1 = StateGraph.shared.slot(initialValue: "hello")
    let r2 = StateGraph.shared.slot(initialValue: 0)
    let r3 = StateGraph.shared.slot(initialValue: true)

    #expect(r1.value as! String == "world")
    #expect(r2.value as! Int == 42)
    #expect(r3.value as! Bool == false)
}

@Test @MainActor func statePersistsValueAcrossFrames() {
    StateGraph.shared.clear()

    // Frame 1: create @State
    var state1 = State(wrappedValue: [1, 2, 3])
    #expect(state1.wrappedValue == [1, 2, 3])
    state1.wrappedValue = [4, 5, 6]

    // Frame 2: recreate @State with same initial value
    StateGraph.shared.resetCounter()
    let state2 = State(wrappedValue: [1, 2, 3])
    #expect(state2.wrappedValue == [4, 5, 6])  // Persisted!
}

@Test @MainActor func stateBindingPersists() {
    StateGraph.shared.clear()

    let state = State(wrappedValue: "initial")
    let binding = state.projectedValue
    binding.wrappedValue = "modified"

    StateGraph.shared.resetCounter()

    let state2 = State(wrappedValue: "initial")
    #expect(state2.wrappedValue == "modified")
}
