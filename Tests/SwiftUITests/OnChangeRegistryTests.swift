import Foundation
import Testing
@testable import SwiftUI

@Test @MainActor func onChangeFirstCallReturnsNil() {
    let registry = OnChangeRegistry.shared
    registry.clear()

    let result = registry.track(value: 42, file: "test", line: 1)
    #expect(result == nil, "First call for a location should return nil")
}

@Test @MainActor func onChangeUnchangedReturnsFalse() {
    let registry = OnChangeRegistry.shared
    registry.clear()

    registry.track(value: 42, file: "test", line: 1)
    let result = registry.track(value: 42, file: "test", line: 1)

    #expect(result != nil)
    let (oldValue, changed) = result!
    #expect(oldValue as? Int == 42)
    #expect(changed == false)
}

@Test @MainActor func onChangeChangedReturnsTrue() {
    let registry = OnChangeRegistry.shared
    registry.clear()

    registry.track(value: 42, file: "test", line: 1)
    let result = registry.track(value: 99, file: "test", line: 1)

    #expect(result != nil)
    let (oldValue, changed) = result!
    #expect(oldValue as? Int == 42)
    #expect(changed == true)
}

@Test @MainActor func onChangeUpdatesStoredValue() {
    let registry = OnChangeRegistry.shared
    registry.clear()

    registry.track(value: 42, file: "test", line: 1)
    registry.track(value: 99, file: "test", line: 1)
    let result = registry.track(value: 99, file: "test", line: 1)

    #expect(result != nil)
    let (oldValue, changed) = result!
    #expect(oldValue as? Int == 99, "Stored value should have been updated to 99")
    #expect(changed == false)
}

@Test @MainActor func onChangeEnqueueAndFlush() {
    let registry = OnChangeRegistry.shared
    registry.clear()

    var log: [String] = []
    registry.enqueue { log.append("first") }
    registry.enqueue { log.append("second") }
    registry.flushActions()

    #expect(log == ["first", "second"])
}

@Test @MainActor func onChangeFlushClearsPending() {
    let registry = OnChangeRegistry.shared
    registry.clear()

    var count = 0
    registry.enqueue { count += 1 }
    registry.flushActions()
    #expect(count == 1)

    registry.flushActions()
    #expect(count == 1, "Second flush should be no-op")
}

@Test @MainActor func onChangeResetCounterPreservesState() {
    let registry = OnChangeRegistry.shared
    registry.clear()

    registry.track(value: 42, file: "test", line: 1)
    registry.resetCounter()
    let result = registry.track(value: 42, file: "test", line: 1)

    #expect(result != nil)
    let (oldValue, changed) = result!
    #expect(oldValue as? Int == 42)
    #expect(changed == false, "resetCounter is no-op, stored value survives")
}

@Test @MainActor func onChangeClearResetsEverything() {
    let registry = OnChangeRegistry.shared
    registry.clear()

    registry.track(value: 42, file: "test", line: 1)
    var flushed = false
    registry.enqueue { flushed = true }
    registry.clear()

    let result = registry.track(value: 42, file: "test", line: 1)
    #expect(result == nil, "After clear, first call returns nil again")

    registry.flushActions()
    #expect(flushed == false, "Pending actions were cleared")
}
