import Testing
import Foundation
@testable import SwiftUI

@Test @MainActor func tagStoresValue() {
    let node = _resolve(Text("Hello")).tag("myTag")
    if case .tagged(let tag, _) = node {
        #expect(tag.value == AnyHashable("myTag"))
    } else {
        Issue.record("Expected .tagged, got \(node)")
    }
}

@Test @MainActor func listSelectionWithTags() {
    TapRegistry.shared.clear()
    TagRegistry.shared.clear()

    var selected: String? = nil
    let binding = Binding<String?>(get: { selected }, set: { selected = $0 })

    let list = List(selection: binding) {
        Text("Apple").tag("apple")
        Text("Banana").tag("banana")
        Text("Cherry").tag("cherry")
    }

    let node = list._nodeRepresentation

    // Find tap IDs in the list
    func findTaps(_ n: ViewNode) -> [UInt64] {
        switch n {
        case .onTap(let id, _): return [id]
        case .list(let children, _): return children.flatMap { findTaps($0) }
        case .vstack(_, _, let children): return children.flatMap { findTaps($0) }
        case .scrollView(_, let children, _): return children.flatMap { findTaps($0) }
        case .padding(_, let child): return findTaps(child)
        default: return []
        }
    }

    let taps = findTaps(node)
    #expect(taps.count == 3, "Each tagged item should have a tap handler")

    // Tap "banana"
    if taps.count >= 2 {
        TapRegistry.shared.fire(id: taps[1])
        #expect(selected == "banana", "Tapping banana tag should set selection to 'banana'")
    }
}
