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

@Test @MainActor func onceRegistrySkipsOnSecondFrame() {
    let registry = OnceRegistry.shared
    registry.clear()

    var count = 0
    // Simulate calling from the same call site across frames
    func callSite() { registry.runOnce { count += 1 } }

    callSite() // frame 1 — fires
    #expect(count == 1)

    registry.resetCounter() // frame 2
    callSite() // same file:line — already fired
    #expect(count == 1, "Same call site should not fire again")
}

@Test @MainActor func onceRegistryDifferentCallSitesFireIndependently() {
    let registry = OnceRegistry.shared
    registry.clear()

    var a = 0
    var b = 0
    // Different lines = different keys
    registry.runOnce { a += 1 }
    registry.runOnce { b += 1 }
    #expect(a == 1)
    #expect(b == 1)
}

@Test @MainActor func onceRegistryPersistsAcrossFrames() {
    let registry = OnceRegistry.shared
    registry.clear()

    var count = 0
    func site1() { registry.runOnce { count += 1 } }
    func site2() { registry.runOnce { count += 1 } }
    func site3() { registry.runOnce { count += 1 } }

    site1(); site2(); site3()
    #expect(count == 3)

    registry.resetCounter()
    site1(); site2(); site3()
    #expect(count == 3, "All 3 sites already fired")
}

@Test @MainActor func onceRegistryClearAllowsRefiring() {
    let registry = OnceRegistry.shared
    registry.clear()

    var count = 0
    func site() { registry.runOnce { count += 1 } }

    site()
    #expect(count == 1)

    registry.clear()
    site()
    #expect(count == 2, "clear() wipes fired set, fires again")
}

@Test @MainActor func onceRegistryClearResetsFiredSet() {
    let registry = OnceRegistry.shared
    registry.clear()

    var count = 0
    func s1() { registry.runOnce { count += 1 } }
    func s2() { registry.runOnce { count += 1 } }
    func s3() { registry.runOnce { count += 1 } }

    s1(); s2(); s3()
    #expect(count == 3)

    registry.clear()
    s1(); s2(); s3()
    #expect(count == 6, "All 3 fire again after clear()")
}
