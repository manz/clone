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
