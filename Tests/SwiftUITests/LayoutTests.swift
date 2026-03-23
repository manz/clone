import Testing
@testable import SwiftUI

// MARK: - Measure tests

@Test func measureText() {
    let node = ViewNode.text("Hello", fontSize: 20, color: .white)
    let size = Layout.measure(node, constraint: SizeConstraint(maxWidth: 400, maxHeight: 300))
    // cosmic-text measures actual glyph widths
    #expect(size.width > 30 && size.width < 100)
    #expect(size.height > 15 && size.height < 35)
}

@Test func measureRectWithExplicitSize() {
    let node = ViewNode.rect(width: 100, height: 50, fill: .white)
    let size = Layout.measure(node, constraint: SizeConstraint(maxWidth: 400, maxHeight: 300))
    #expect(size.width == 100)
    #expect(size.height == 50)
}

@Test func measureRectFillsConstraintWhenNil() {
    let node = ViewNode.rect(width: nil, height: nil, fill: .white)
    let size = Layout.measure(node, constraint: SizeConstraint(maxWidth: 400, maxHeight: 300))
    #expect(size.width == 400)
    #expect(size.height == 300)
}

@Test func measureRoundedRect() {
    let node = ViewNode.roundedRect(width: 200, height: 100, radius: 12, fill: .white)
    let size = Layout.measure(node, constraint: SizeConstraint(maxWidth: 400, maxHeight: 300))
    #expect(size.width == 200)
    #expect(size.height == 100)
}

@Test func measureVStack() {
    let node = ViewNode.vstack(alignment: .center, spacing: 10, children: [
        .rect(width: 100, height: 50, fill: .white),
        .rect(width: 200, height: 30, fill: .white),
    ])
    let size = Layout.measure(node, constraint: SizeConstraint(maxWidth: 400, maxHeight: 600))
    // height: 50 + 10 + 30 = 90, width: max(100, 200) = 200
    #expect(size.width == 200)
    #expect(size.height == 90)
}

@Test func measureHStack() {
    let node = ViewNode.hstack(alignment: .center, spacing: 8, children: [
        .rect(width: 100, height: 50, fill: .white),
        .rect(width: 60, height: 80, fill: .white),
    ])
    let size = Layout.measure(node, constraint: SizeConstraint(maxWidth: 400, maxHeight: 300))
    // width: 100 + 8 + 60 = 168, height: max(50, 80) = 80
    #expect(size.width == 168)
    #expect(size.height == 80)
}

@Test func measurePadding() {
    let node = ViewNode.padding(
        EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20),
        child: .rect(width: 100, height: 50, fill: .white)
    )
    let size = Layout.measure(node, constraint: SizeConstraint(maxWidth: 400, maxHeight: 300))
    #expect(size.width == 140) // 100 + 20 + 20
    #expect(size.height == 70) // 50 + 10 + 10
}

@Test func measureFrame() {
    let node = ViewNode.frame(width: 300, height: nil, child: .rect(width: 100, height: 50, fill: .white))
    let size = Layout.measure(node, constraint: SizeConstraint(maxWidth: 400, maxHeight: 300))
    #expect(size.width == 300) // overridden
    #expect(size.height == 50) // from child
}

// MARK: - Layout tests

@Test func layoutVStackPositioning() {
    let node = ViewNode.vstack(alignment: .center, spacing: 10, children: [
        .rect(width: 100, height: 40, fill: .white),
        .rect(width: 200, height: 60, fill: .white),
    ])
    let result = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 400, height: 300))
    #expect(result.children.count == 2)

    let first = result.children[0]
    #expect(first.frame.y == 0)
    #expect(first.frame.width == 100)
    #expect(first.frame.height == 40)
    // Centered: (400 - 100) / 2 = 150
    #expect(first.frame.x == 150)

    let second = result.children[1]
    #expect(second.frame.y == 50) // 40 + 10 spacing
    // Centered: (400 - 200) / 2 = 100
    #expect(second.frame.x == 100)
}

@Test func layoutHStackPositioning() {
    let node = ViewNode.hstack(alignment: .center, spacing: 8, children: [
        .rect(width: 100, height: 50, fill: .white),
        .rect(width: 60, height: 30, fill: .white),
    ])
    let result = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 400, height: 200))
    #expect(result.children.count == 2)

    let first = result.children[0]
    #expect(first.frame.x == 0)
    #expect(first.frame.width == 100)
    // Center-aligned vertically: (200 - 50) / 2 = 75
    #expect(first.frame.y == 75)

    let second = result.children[1]
    #expect(second.frame.x == 108) // 100 + 8
    // Center-aligned: (200 - 30) / 2 = 85
    #expect(second.frame.y == 85)
}

@Test func layoutVStackWithSpacer() {
    let node = ViewNode.vstack(alignment: .center, spacing: 0, children: [
        .rect(width: 100, height: 40, fill: .white),
        .spacer(minLength: 0),
        .rect(width: 100, height: 40, fill: .white),
    ])
    let result = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 400, height: 300))
    #expect(result.children.count == 3)

    // First child at top
    #expect(result.children[0].frame.y == 0)
    // Spacer fills: 300 - 40 - 40 = 220
    #expect(result.children[1].frame.height == 220)
    // Last child pushed to bottom: 40 (first) + 220 (spacer) = 260
    #expect(result.children[2].frame.y == 260)
}

@Test func layoutVStackLeadingAlignment() {
    let node = ViewNode.vstack(alignment: .leading, spacing: 0, children: [
        .rect(width: 100, height: 40, fill: .white),
        .rect(width: 200, height: 40, fill: .white),
    ])
    let result = Layout.layout(node, in: LayoutFrame(x: 10, y: 0, width: 400, height: 300))
    #expect(result.children[0].frame.x == 10)
    #expect(result.children[1].frame.x == 10)
}

@Test func layoutVStackTrailingAlignment() {
    let node = ViewNode.vstack(alignment: .trailing, spacing: 0, children: [
        .rect(width: 100, height: 40, fill: .white),
        .rect(width: 200, height: 40, fill: .white),
    ])
    let result = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 400, height: 300))
    #expect(result.children[0].frame.x == 300) // 400 - 100
    #expect(result.children[1].frame.x == 200) // 400 - 200
}

@Test func layoutNestedStacksProduceCorrectPositions() {
    let node = ViewNode.vstack(alignment: .leading, spacing: 10, children: [
        .hstack(alignment: .center, spacing: 8, children: [
            .rect(width: 50, height: 50, fill: .blue),
            .text("Label", fontSize: 16, color: .primary),
        ]),
        .roundedRect(width: 300, height: 100, radius: 12, fill: .white),
    ])
    let result = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 400, height: 600))
    #expect(result.children.count == 2)

    // HStack child
    let hstack = result.children[0]
    #expect(hstack.children.count == 2)
    #expect(hstack.children[0].frame.x == 0)  // rect at x=0
    #expect(hstack.children[1].frame.x == 58) // 50 + 8

    // RoundedRect below
    let rrect = result.children[1]
    #expect(rrect.frame.y == 60) // 50 (hstack height) + 10 spacing
}

// MARK: - Background / ZStack measurement

@Test func backgroundRectSizedByContent() {
    // .background(Color.blue) creates ZStack with [nil-rect, content]
    // The ZStack should be sized by the content, not the nil-rect
    let content = ViewNode.text("Hello", fontSize: 20, color: .white)
    let node = content.background(.blue)
    let size = Layout.measure(node, constraint: SizeConstraint(maxWidth: 600, maxHeight: 400))
    // Should be sized by text, NOT by constraint (600x400)
    #expect(size.width > 30 && size.width < 100)
    #expect(size.height > 15 && size.height < 35)
}

@Test func backgroundRectLayoutFillsParentFrame() {
    // .background() creates a ZStack — the nil-rect fills the ZStack's layout frame
    let content = ViewNode.rect(width: 200, height: 50, fill: .white)
    let node = content.background(.blue)
    let result = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 600, height: 400))
    let commands = CommandFlattener.flatten(result)
    // Should have 2 rect commands
    let rects = commands.filter { if case .rect = $0.kind { return true }; return false }
    #expect(rects.count == 2)
}

@Test func zstackNilRectDoesNotInflate() {
    // A ZStack with nil-rect and sized content should measure as the content
    let node = ViewNode.zstack(children: [
        .rect(width: nil, height: nil, fill: .red),
        .rect(width: 100, height: 50, fill: .white),
    ])
    let size = Layout.measure(node, constraint: SizeConstraint(maxWidth: 600, maxHeight: 400))
    #expect(size.width == 100)
    #expect(size.height == 50)
}

@Test func zstackAllNilRectsFallsBackToConstraint() {
    // If all children are nil-rects, fall back to constraint
    let node = ViewNode.zstack(children: [
        .rect(width: nil, height: nil, fill: .red),
    ])
    let size = Layout.measure(node, constraint: SizeConstraint(maxWidth: 600, maxHeight: 400))
    #expect(size.width == 600)
    #expect(size.height == 400)
}

@Test func zstackTopLeadingAlignment() {
    let node = ViewNode.zstack(alignment: .topLeading, children: [
        .rect(width: nil, height: nil, fill: .gray),
        .rect(width: 100, height: 50, fill: .red),
    ])
    let layoutNode = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 600, height: 400))
    // Second child (100x50) should be at top-left, not centered
    let child = layoutNode.children[1]
    #expect(child.frame.x == 0)
    #expect(child.frame.y == 0)
    #expect(child.frame.width == 100)
    #expect(child.frame.height == 50)
}

@Test func zstackBottomTrailingAlignment() {
    let node = ViewNode.zstack(alignment: .bottomTrailing, children: [
        .rect(width: nil, height: nil, fill: .gray),
        .rect(width: 100, height: 50, fill: .red),
    ])
    let layoutNode = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 600, height: 400))
    let child = layoutNode.children[1]
    #expect(child.frame.x == 500)
    #expect(child.frame.y == 350)
}

@Test func zstackCenterAlignmentDefault() {
    let node = ViewNode.zstack(children: [
        .rect(width: nil, height: nil, fill: .gray),
        .rect(width: 100, height: 50, fill: .red),
    ])
    let layoutNode = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 600, height: 400))
    let child = layoutNode.children[1]
    #expect(child.frame.x == 250)
    #expect(child.frame.y == 175)
}

@Test func layoutNoNaNCoordinates() {
    // frame(maxWidth: .infinity) inside a vstack should not produce NaN
    let node = ViewNode.vstack(alignment: .center, spacing: 8, children: [
        .frame(width: .infinity, height: nil, child: .text("Button", fontSize: 14, color: .white)),
        .text("Label", fontSize: 14, color: .white),
    ])
    let result = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 400, height: 300))
    let commands = CommandFlattener.flatten(result)
    for cmd in commands {
        #expect(cmd.x.isFinite, "x should not be NaN/inf: \(cmd)")
        #expect(cmd.y.isFinite, "y should not be NaN/inf: \(cmd)")
    }
}

// MARK: - Grid layout tests

@Test func gridAdaptiveColumnCount() {
    // 600px wide, adaptive minimum 220 → floor((600+8)/(220+8)) = 2 columns
    let count = Layout.gridColumnCount(
        [GridColumnSpec(.adaptive(min: 220, max: .infinity))],
        availableWidth: 600, spacing: 8
    )
    #expect(count == 2)
}

@Test func gridAdaptiveNarrow() {
    // 200px wide, adaptive minimum 220 → 1 column (can't fit 2)
    let count = Layout.gridColumnCount(
        [GridColumnSpec(.adaptive(min: 220, max: .infinity))],
        availableWidth: 200, spacing: 8
    )
    #expect(count == 1)
}

@Test func gridAdaptiveWide() {
    // 1000px wide, adaptive minimum 170 → floor((1000+8)/(170+8)) = 5 columns
    let count = Layout.gridColumnCount(
        [GridColumnSpec(.adaptive(min: 170, max: .infinity))],
        availableWidth: 1000, spacing: 8
    )
    #expect(count == 5)
}

@Test @MainActor func gridLayoutPositionsChildren() {
    let node = ViewNode.grid(
        columns: [GridColumnSpec(.adaptive(min: 100, max: .infinity))],
        spacing: 8,
        children: [
            .rect(width: 100, height: 50, fill: .red),
            .rect(width: 100, height: 50, fill: .blue),
            .rect(width: 100, height: 50, fill: .green),
        ]
    )
    let result = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 300, height: 400))
    // 300px / (100+8) = 2.7 → 2 columns, each ~146px
    // Row 1: [red, blue], Row 2: [green]
    #expect(result.children.count == 3)
    // First child at x=0
    #expect(result.children[0].frame.x == 0)
    // Second child offset to second column
    #expect(result.children[1].frame.x > 100)
    // Third child on next row, x=0
    #expect(result.children[2].frame.x == 0)
    #expect(result.children[2].frame.y > 50)
}

// MARK: - CommandFlattener tests

@Test func flattenSimpleRect() {
    let node = ViewNode.rect(width: 100, height: 50, fill: .blue)
    let layoutResult = Layout.layout(node, in: LayoutFrame(x: 10, y: 20, width: 400, height: 300))
    let commands = CommandFlattener.flatten(layoutResult)
    #expect(commands.count == 1)
    #expect(commands[0].x == 10)
    #expect(commands[0].y == 20)
    #expect(commands[0].kind == .rect(color: .blue))
}

@Test func flattenOpacityModifiesAlpha() {
    let node = ViewNode.opacity(0.5, child: .rect(width: 100, height: 50, fill: .white))
    let layoutResult = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 400, height: 300))
    let commands = CommandFlattener.flatten(layoutResult)
    #expect(commands.count == 1)
    if case .rect(let color) = commands[0].kind {
        #expect(color.a == 0.5)
    } else {
        Issue.record("Expected rect command")
    }
}

@Test func flattenVStackProducesMultipleCommands() {
    let node = ViewNode.vstack(alignment: .center, spacing: 10, children: [
        .rect(width: 100, height: 40, fill: .red),
        .roundedRect(width: 200, height: 60, radius: 8, fill: .green),
    ])
    let layoutResult = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 400, height: 300))
    let commands = CommandFlattener.flatten(layoutResult)
    #expect(commands.count == 2)
    #expect(commands[0].kind == .rect(color: .red))
    #expect(commands[1].kind == .roundedRect(radius: 8, color: .green))
}
