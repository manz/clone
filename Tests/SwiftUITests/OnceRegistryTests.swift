import Foundation
import Testing
@testable import SwiftUI

@Test @MainActor func onceRegistryFiresOnFirstCall() {
    let registry = OnceRegistry.shared
    registry.clear()

    var count = 0
    registry.runOnce { count += 1 }
    #expect(count == 1)
}

@Test @MainActor func onceRegistrySkipsAfterResetCounter() {
    let registry = OnceRegistry.shared
    registry.clear()

    var count = 0
    registry.runOnce { count += 1 }
    #expect(count == 1)

    // Simulate next frame — counter resets but fired persists
    registry.resetCounter()
    registry.runOnce { count += 1 }
    #expect(count == 1, "Key 0 already in fired set, should not fire again")
}

@Test @MainActor func onceRegistryDifferentCallSitesFireIndependently() {
    let registry = OnceRegistry.shared
    registry.clear()

    var a = 0
    var b = 0
    registry.runOnce { a += 1 } // key 0
    registry.runOnce { b += 1 } // key 1
    #expect(a == 1)
    #expect(b == 1)
}

@Test @MainActor func onceRegistryCounterResetsButFiredPersists() {
    let registry = OnceRegistry.shared
    registry.clear()

    var count = 0
    registry.runOnce { count += 1 } // key 0
    registry.runOnce { count += 1 } // key 1
    registry.runOnce { count += 1 } // key 2
    #expect(count == 3)

    // Next frame — same 3 call sites should all be skipped
    registry.resetCounter()
    registry.runOnce { count += 1 } // key 0 — already fired
    registry.runOnce { count += 1 } // key 1 — already fired
    registry.runOnce { count += 1 } // key 2 — already fired
    #expect(count == 3, "All 3 keys already in fired set")
}

@Test @MainActor func onceRegistryClearAllowsRefiring() {
    let registry = OnceRegistry.shared
    registry.clear()

    var count = 0
    registry.runOnce { count += 1 }
    #expect(count == 1)

    registry.clear()
    registry.runOnce { count += 1 }
    #expect(count == 2, "clear() wipes fired set, key 0 fires again")
}

@Test @MainActor func onceRegistryClearResetsFiredSet() {
    let registry = OnceRegistry.shared
    registry.clear()

    var count = 0
    registry.runOnce { count += 1 }
    registry.runOnce { count += 1 }
    registry.runOnce { count += 1 }
    #expect(count == 3)

    registry.clear()
    registry.runOnce { count += 1 }
    registry.runOnce { count += 1 }
    registry.runOnce { count += 1 }
    #expect(count == 6, "All 3 fire again after clear()")
}
