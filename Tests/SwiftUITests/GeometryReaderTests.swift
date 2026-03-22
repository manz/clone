import Foundation
import Testing
@testable import SwiftUI

@Test @MainActor func geometryReaderReceivesProposedSize() {
    GeometryReaderRegistry.shared.clear()

    let captured = CapturedValue<CGSize>()
    let gr = GeometryReader { proxy in
        captured.value = proxy.size
        return RoundedRectangle(cornerRadius: 8)
            .fill(.blue)
            .frame(width: proxy.width, height: proxy.height)
    }
    let node = _resolve(gr)

    let result = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 400, height: 300))

    #expect(captured.value != nil)
    #expect(captured.value!.width == 400)
    #expect(captured.value!.height == 300)
    #expect(result.frame.width == 400)
    #expect(result.frame.height == 300)
}

@Test @MainActor func geometryReaderFillsParent() {
    GeometryReaderRegistry.shared.clear()

    let gr = GeometryReader { proxy in
        Rectangle().fill(.gray).frame(width: proxy.width, height: proxy.height)
    }
    let node = _resolve(gr)

    let size = Layout.measure(node, constraint: SizeConstraint(maxWidth: 800, maxHeight: 600))
    #expect(size.width == 800)
    #expect(size.height == 600)
}

@Test @MainActor func geometryReaderInsideVStack() {
    GeometryReaderRegistry.shared.clear()

    let captured = CapturedValue<CGSize>()
    let gr = GeometryReader { proxy in
        captured.value = proxy.size
        return Color.clear
    }
    let vstack = ViewNode.vstack(alignment: .leading, spacing: 0, children: [
        .rect(width: nil, height: 100, fill: .red),
        _resolve(gr),
    ])

    let _ = Layout.layout(vstack, in: LayoutFrame(x: 0, y: 0, width: 600, height: 400))

    #expect(captured.value != nil)
    // GeometryReader fills remaining space: 400 - 100 = 300
    #expect(captured.value!.width == 600)
    #expect(captured.value!.height == 300)
}

/// Helper to capture values from closures.
final class CapturedValue<T> {
    var value: T?
}
