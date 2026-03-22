import Testing
import Foundation
@testable import SwiftUI

@Test @MainActor func stateGraphPersistsAcrossResets() {
    StateGraph.shared.clear()

    let slot1 = StateGraph.shared.slot(initialValue: 42, file: "test", line: 1)
    #expect(slot1.value as! Int == 42)

    slot1.value = 99

    // Same file+line gets same slot
    let slot2 = StateGraph.shared.slot(initialValue: 42, file: "test", line: 1)
    #expect(slot2.value as! Int == 99)  // Persisted, not reset to 42
}

@Test @MainActor func stateGraphDifferentLocations() {
    StateGraph.shared.clear()

    let s1 = StateGraph.shared.slot(initialValue: "hello", file: "test", line: 10)
    let s2 = StateGraph.shared.slot(initialValue: 0, file: "test", line: 20)

    s1.value = "world"
    s2.value = 42

    let r1 = StateGraph.shared.slot(initialValue: "hello", file: "test", line: 10)
    let r2 = StateGraph.shared.slot(initialValue: 0, file: "test", line: 20)

    #expect(r1.value as! String == "world")
    #expect(r2.value as! Int == 42)
}

@Test @MainActor func statePersistsValueAcrossFrames() {
    StateGraph.shared.clear()

    // Use explicit file/line to simulate same source location
    var state1 = State(wrappedValue: [1, 2, 3], file: "TestView.swift", line: 5)
    #expect(state1.wrappedValue == [1, 2, 3])
    state1.wrappedValue = [4, 5, 6]

    // Same file+line gets persisted value
    let state2 = State(wrappedValue: [1, 2, 3], file: "TestView.swift", line: 5)
    #expect(state2.wrappedValue == [4, 5, 6])  // Persisted!
}

@Test @MainActor func stateBindingPersists() {
    StateGraph.shared.clear()

    let state = State(wrappedValue: "initial", file: "TestView.swift", line: 10)
    let binding = state.projectedValue
    binding.wrappedValue = "modified"

    let state2 = State(wrappedValue: "initial", file: "TestView.swift", line: 10)
    #expect(state2.wrappedValue == "modified")
}
