import Foundation
import Testing
@testable import SwiftUI

@Test @MainActor func hoverHandlerSurvivesFrameRebuild() {
    // Simulates the dock's onContinuousHover across two frame rebuilds.
    // The bug: registries used clear() which destroyed handlers AND reset IDs.
    // After a frame rebuild, IDs drifted → activeIds mismatched → .ended fired → flash.
    // The fix: resetCounter() resets IDs but keeps handlers and activeIds,
    // same pattern as StateGraph.resetCounter().

    let registry = HoverRegistry.shared
    var phase: HoverPhase? = nil

    // --- Frame 1: build view tree, register handler ---
    registry.clear()
    let id1 = registry.registerContinuous { p in phase = p }

    // Pointer moves over the hover zone
    registry.update(positions: [id1: CGPoint(x: 100, y: 100)])
    #expect(phase == .active(CGPoint(x: 100, y: 100)))

    // --- Frame 2: resetCounter (NOT clear) before rebuilding ---
    registry.resetCounter()
    let id2 = registry.registerContinuous { p in phase = p }

    // IDs must be stable: same call sequence → same ID
    #expect(id1 == id2, "Handler ID should restart at 1 after resetCounter()")

    // Pointer moves again — activeIds already has id1 which == id2,
    // so this is "still hovered", not "newly hovered then old left"
    phase = nil
    registry.update(positions: [id2: CGPoint(x: 110, y: 100)])
    #expect(phase == .active(CGPoint(x: 110, y: 100)),
            "Handler must fire .active after frame rebuild, not .ended")
}

@Test @MainActor func hoverEndedWithoutResetCounterCausesIdDrift() {
    // Demonstrates the bug: without resetCounter between frames, IDs drift.
    // The old code called clear() in onPointerMove, which nuked handlers entirely.
    // Even keeping handlers but not resetting the counter causes drift.

    let registry = HoverRegistry.shared
    var phases: [HoverPhase] = []

    // --- Frame 1 ---
    registry.clear()
    let id1 = registry.registerContinuous { p in phases.append(p) }
    registry.update(positions: [id1: CGPoint(x: 100, y: 100)])
    #expect(phases.count == 1)

    // --- Frame 2: register WITHOUT resetting counter (the broken behavior) ---
    let id2 = registry.registerContinuous { p in phases.append(p) }
    #expect(id2 != id1, "Without resetCounter, IDs drift")

    // Pointer moves — new layout has id2, but activeIds still has id1
    phases.removeAll()
    registry.update(positions: [id2: CGPoint(x: 110, y: 100)])

    // The old handler (id1) gets .ended because it left activeIds
    let hasEnded = phases.contains(.ended)
    #expect(hasEnded, "Stale ID fires .ended — this is the drift bug")

    registry.clear()
}

@Test @MainActor func tapRegistryResetCounterKeepsHandlers() {
    let registry = TapRegistry.shared
    var fired = false

    registry.clear()
    let id1 = registry.register { fired = true }

    // Frame 2: resetCounter, re-register
    registry.resetCounter()
    let id2 = registry.register { fired = true }
    #expect(id1 == id2, "Same call sequence → same ID")

    // Fire by ID should work
    registry.fire(id: id2)
    #expect(fired)

    registry.clear()
}

@Test @MainActor func tagRegistryResetCounterKeepsTags() {
    let registry = TagRegistry.shared

    registry.clear()
    let id1 = registry.register("finder")

    // Frame 2: resetCounter, re-register
    registry.resetCounter()
    let id2 = registry.register("finder")
    #expect(id1 == id2)
    #expect(registry.value(for: id2) == AnyHashable("finder"))

    registry.clear()
}

@Test @MainActor func textFieldRegistryResetCounterPreservesFocus() {
    let registry = TextFieldRegistry.shared

    registry.reset()
    var text1 = ""
    let binding1 = Binding(get: { text1 }, set: { text1 = $0 })
    let id1 = registry.register(binding: binding1, placeholder: "Name")
    registry.focus(id: id1)
    #expect(registry.focusedId == id1)

    // Frame 2: resetCounter, re-register
    registry.resetCounter()
    var text2 = ""
    let binding2 = Binding(get: { text2 }, set: { text2 = $0 })
    let id2 = registry.register(binding: binding2, placeholder: "Name")
    #expect(id1 == id2, "Same call sequence → same ID")
    #expect(registry.focusedId == id2, "Focus must survive frame rebuild")

    registry.reset()
}
