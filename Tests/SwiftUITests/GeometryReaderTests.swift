import Testing
import Foundation
@testable import SwiftUI

@Test func geometryReaderReceivesProposedSize() {
    GeometryReaderRegistry.shared.clear()

    let captured = CapturedValue<CGSize>()
    let node = GeometryReader { proxy in
        captured.value = proxy.size
        return RoundedRectangle(cornerRadius: 8)
            .fill(.blue)
            .frame(width: proxy.width, height: proxy.height)
    }

    let result = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 400, height: 300))

    #expect(captured.value != nil)
    #expect(captured.value!.width == 400)
    #expect(captured.value!.height == 300)
    #expect(result.frame.width == 400)
    #expect(result.frame.height == 300)
}

@Test func geometryReaderFillsParent() {
    GeometryReaderRegistry.shared.clear()

    let node = GeometryReader { proxy in
        Rectangle().fill(.gray).frame(width: proxy.width, height: proxy.height)
    }

    let size = Layout.measure(node, constraint: SizeConstraint(maxWidth: 800, maxHeight: 600))
    #expect(size.width == 800)
    #expect(size.height == 600)
}

@Test func geometryReaderInsideVStack() {
    GeometryReaderRegistry.shared.clear()

    // Use a shared box to capture from inside the closure
    let captured = CapturedValue<Float>()
    let node = VStack(spacing: 0) {
        RoundedRectangle(cornerRadius: 0)
            .fill(.gray)
            .frame(width: nil, height: 50)
        GeometryReader { proxy in
            captured.value = proxy.height
            return Text("Content area")
        }
    }

    let _ = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 400, height: 300))

    #expect(captured.value != nil)
}

@Test func geometryReaderReceivesCorrectFrame() {
    GeometryReaderRegistry.shared.clear()

    let captured = CapturedValue<LayoutFrame>()
    let node = ViewNode.padding(
        EdgeInsets(top: 20, leading: 30, bottom: 0, trailing: 0),
        child: GeometryReader { proxy in
            captured.value = proxy.frame
            return Rectangle().fill(.gray)
        }
    )

    let _ = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 400, height: 300))

    #expect(captured.value != nil)
    #expect(captured.value!.x == 30)
    #expect(captured.value!.y == 20)
    #expect(captured.value!.width == 370)
    #expect(captured.value!.height == 280)
}

// Helper to capture values from inside closures
final class CapturedValue<T> {
    var value: T?
}

@Test func hitTestOnLayoutNode() {
    let node = ZStack {
        Rectangle().fill(.gray).frame(width: 400, height: 300)
        RoundedRectangle(cornerRadius: 8)
            .fill(.blue)
            .frame(width: 100, height: 50)
    }

    let result = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 400, height: 300))

    // Hit inside the rounded rect (at origin since zstack overlays)
    let hit = result.hitTest(x: 10, y: 10)
    #expect(hit != nil)

    // Hit outside the whole frame
    let miss = result.hitTest(x: 500, y: 500)
    #expect(miss == nil)
}
