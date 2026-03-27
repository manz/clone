import Testing
import Foundation
@testable import SwiftUI

@Test func textMeasureSingleLineWithoutConstraint() {
    let size = TextMeasurer.measure("Hello world", fontSize: 14, weight: .regular)
    #expect(size.width > 0, "Text should have positive width")
    #expect(size.height > 0, "Text should have positive height")
    // Single line — height should be approximately one line
    #expect(size.height < 30, "Single line should be less than 30pt tall, got \(size.height)")
}

@Test func textMeasureWrapsWithMaxWidth() {
    let longText = "This is a long sentence that should definitely wrap when given a narrow width constraint for the layout engine"
    let unconstrained = TextMeasurer.measure(longText, fontSize: 14, weight: .regular)
    let constrained = TextMeasurer.measure(longText, fontSize: 14, weight: .regular, maxWidth: 100)

    #expect(unconstrained.width > 100, "Unconstrained text should be wider than 100pt, got \(unconstrained.width)")
    #expect(constrained.width <= 101, "Constrained text should wrap within 100pt, got \(constrained.width)")
    #expect(constrained.height > unconstrained.height, "Wrapped text should be taller (\(constrained.height)) than single line (\(unconstrained.height))")
}

@Test func textMeasureWrappedHeightGrowsWithMoreText() {
    let short = "Hello"
    let long = "Hello world this is a test of word wrapping in the text measurement system"

    let shortSize = TextMeasurer.measure(short, fontSize: 14, weight: .regular, maxWidth: 100)
    let longSize = TextMeasurer.measure(long, fontSize: 14, weight: .regular, maxWidth: 100)

    #expect(longSize.height > shortSize.height, "More text should produce taller wrapped block")
}

@Test @MainActor func layoutPassesConstraintToText() {
    TapRegistry.shared.clear()
    WindowState.shared.update(width: 300, height: 200)

    let longText = "This is a long sentence that should wrap within the frame width constraint"
    let node = ViewNode.frame(width: 120, height: nil, child:
        .text(longText, fontSize: 14, color: .primary)
    )

    let layoutNode = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 300, height: 200))

    // The frame should be 120pt wide
    #expect(layoutNode.frame.width == 120 || layoutNode.frame.width <= 121,
            "Frame should constrain to 120pt, got \(layoutNode.frame.width)")

    // The text child should wrap, making the frame taller than a single line
    let singleLineHeight = TextMeasurer.measure(longText, fontSize: 14, weight: .regular).height
    #expect(layoutNode.frame.height > singleLineHeight,
            "Wrapped text frame should be taller than single line height \(singleLineHeight), got \(layoutNode.frame.height)")
}

@Test func lineLimitPreventsWrapping() {
    let longText = "This is a long line that would normally wrap in a narrow frame"

    // Measure with constraint — text wraps
    let wrappedSize = TextMeasurer.measure(longText, fontSize: 14, weight: .regular, maxWidth: 100)
    let singleLineSize = TextMeasurer.measure(longText, fontSize: 14, weight: .regular)

    #expect(wrappedSize.height > singleLineSize.height,
            "Wrapped text should be taller than single line")

    // lineLimit(1) in layout should measure child unconstrained
    let constraint = SizeConstraint(maxWidth: 100, maxHeight: 200)
    let limitedNode = ViewNode.lineLimit(limit: 1, child:
        .text(longText, fontSize: 14, color: .primary)
    )
    let measured = Layout.measure(limitedNode, constraint: constraint)

    // lineLimit(1) should produce single-line measurement despite narrow constraint
    #expect(measured.width > 100,
            "lineLimit(1) text should overflow constraint, got \(measured.width)")
    #expect(measured.height <= singleLineSize.height + 1,
            "lineLimit(1) text should stay single line (\(singleLineSize.height)), got \(measured.height)")
}

@Test func textMeasureCachesWrappedAndUnwrapped() {
    let text = "Cache test string"
    let unwrapped = TextMeasurer.measure(text, fontSize: 14, weight: .regular)
    let wrapped = TextMeasurer.measure(text, fontSize: 14, weight: .regular, maxWidth: 50)

    // Calling again should return same values (cached)
    let unwrapped2 = TextMeasurer.measure(text, fontSize: 14, weight: .regular)
    let wrapped2 = TextMeasurer.measure(text, fontSize: 14, weight: .regular, maxWidth: 50)

    #expect(unwrapped.width == unwrapped2.width)
    #expect(wrapped.width == wrapped2.width)
    // Wrapped and unwrapped should be different
    #expect(unwrapped.width != wrapped.width || unwrapped.height != wrapped.height,
            "Wrapped and unwrapped should produce different sizes")
}

// MARK: - Cursor position tests

@Test func cursorPositionAtStartIsZero() {
    let pos = TextMeasurer.cursorPosition(in: "Hello", at: 0, fontSize: 14)
    #expect(pos.x == 0, "Cursor at start should have x=0, got \(pos.x)")
    #expect(pos.y == 0, "Cursor at start should have y=0, got \(pos.y)")
    #expect(pos.height > 0, "Cursor height should be positive, got \(pos.height)")
}

@Test func cursorPositionAdvancesWithOffset() {
    let pos0 = TextMeasurer.cursorPosition(in: "Hello", at: 0, fontSize: 14)
    let pos3 = TextMeasurer.cursorPosition(in: "Hello", at: 3, fontSize: 14)
    let pos5 = TextMeasurer.cursorPosition(in: "Hello", at: 5, fontSize: 14)

    #expect(pos3.x > pos0.x, "Cursor at offset 3 should be right of offset 0")
    #expect(pos5.x > pos3.x, "Cursor at offset 5 should be right of offset 3")
    // All on same visual line
    #expect(pos0.y == pos3.y && pos3.y == pos5.y, "All cursors should be on same visual line")
}

@Test func cursorPositionWrapsToNextVisualLine() {
    let longText = "This is a long sentence that will wrap when constrained to a narrow width"
    let maxWidth: CGFloat = 100

    // Cursor at start: on first visual line
    let posStart = TextMeasurer.cursorPosition(in: longText, at: 0, fontSize: 14, maxWidth: maxWidth)
    // Cursor near end: should be on a later visual line
    let posEnd = TextMeasurer.cursorPosition(in: longText, at: longText.count, fontSize: 14, maxWidth: maxWidth)

    #expect(posEnd.y > posStart.y,
            "Cursor at end of wrapped text should be on a later visual line (y=\(posEnd.y) vs y=\(posStart.y))")
}

@Test func cursorPositionEmptyStringReturnsOrigin() {
    let pos = TextMeasurer.cursorPosition(in: "", at: 0, fontSize: 14)
    // Special case handled in TextMeasurer: empty text returns (0, 0, lineHeight)
    #expect(pos.x == 0)
    #expect(pos.y == 0)
    #expect(pos.height > 0)
}

@Test func cursorPositionEndOfLineMatchesTextWidth() {
    let text = "Hello"
    let textWidth = TextMeasurer.measure(text, fontSize: 14, weight: .regular).width
    let posEnd = TextMeasurer.cursorPosition(in: text, at: text.count, fontSize: 14)

    // Cursor at end should be approximately at the text width
    #expect(abs(posEnd.x - textWidth) < 2,
            "Cursor at end (\(posEnd.x)) should be near text width (\(textWidth))")
}

// MARK: - Spatial tap tests

@Test @MainActor func spatialTapHandlerReceivesCoordinates() {
    TapRegistry.shared.clear()

    var receivedPoint: CGPoint? = nil
    let id = TapRegistry.shared.registerSpatial { point in
        receivedPoint = point
    }

    TapRegistry.shared.fire(id: id, at: CGPoint(x: 42, y: 99))
    #expect(receivedPoint != nil, "Spatial handler should have been called")
    #expect(receivedPoint?.x == 42, "X should be 42, got \(receivedPoint?.x ?? -1)")
    #expect(receivedPoint?.y == 99, "Y should be 99, got \(receivedPoint?.y ?? -1)")
}

@Test @MainActor func hitTestTapReturnsFrame() {
    TapRegistry.shared.clear()

    let tapId = TapRegistry.shared.register {}
    let child = ViewNode.text("Click me", fontSize: 14, color: .primary)
    let tapNode = ViewNode.onTap(id: tapId, child: child)

    let layoutNode = Layout.layout(tapNode, in: LayoutFrame(x: 50, y: 30, width: 200, height: 40))
    let hit = layoutNode.hitTestTap(x: 60, y: 35)

    #expect(hit != nil, "Should hit the tap node")
    if case .tap(let id, let hitFrame) = hit {
        #expect(id == tapId, "Should return correct tap ID")
        #expect(hitFrame.x == 50, "Frame x should be 50, got \(hitFrame.x)")
        #expect(hitFrame.y == 30, "Frame y should be 30, got \(hitFrame.y)")
    } else {
        #expect(Bool(false), "Expected .tap result")
    }
}

@Test @MainActor func hitTestTapMissReturnsNil() {
    TapRegistry.shared.clear()

    let tapId = TapRegistry.shared.register {}
    let child = ViewNode.text("Click me", fontSize: 14, color: .primary)
    let tapNode = ViewNode.onTap(id: tapId, child: child)

    let layoutNode = Layout.layout(tapNode, in: LayoutFrame(x: 50, y: 30, width: 200, height: 40))
    let hit = layoutNode.hitTestTap(x: 0, y: 0)  // Outside the frame

    #expect(hit == nil, "Should not hit anything outside the frame")
}

// MARK: - Dynamic line height in VStack

@Test func vstackWithWrappedTextHasDynamicHeight() {
    // Two lines: one short, one that wraps at narrow width
    let shortLine = ViewNode.text("Hi", fontSize: 14, color: .primary)
    let longLine = ViewNode.text("This is a much longer line that should wrap", fontSize: 14, color: .primary)

    let vstack = ViewNode.vstack(alignment: .leading, spacing: 0, children: [shortLine, longLine])
    let constraint = SizeConstraint(maxWidth: 100, maxHeight: 500)

    let shortSize = Layout.measure(shortLine, constraint: constraint)
    let longSize = Layout.measure(longLine, constraint: constraint)
    let vstackSize = Layout.measure(vstack, constraint: constraint)

    // VStack height should be sum of both lines
    let expectedHeight = shortSize.height + longSize.height
    #expect(abs(vstackSize.height - expectedHeight) < 1,
            "VStack height (\(vstackSize.height)) should equal sum of line heights (\(expectedHeight))")

    // Long line should be taller than short line (it wraps)
    #expect(longSize.height > shortSize.height,
            "Wrapped line should be taller (\(longSize.height)) than short line (\(shortSize.height))")
}
