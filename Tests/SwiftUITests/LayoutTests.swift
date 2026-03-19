import Testing
@testable import SwiftUI

// MARK: - Measure tests

@Test func measureText() {
    let node = ViewNode.text("Hello", fontSize: 20, color: .white)
    let size = Layout.measure(node, constraint: SizeConstraint(maxWidth: 400, maxHeight: 300))
    // 5 chars * 20 * 0.6 = 60
    #expect(size.width == 60)
    #expect(size.height == 20)
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
    let node = ViewNode.roundedRect(width: 200, height: 100, radius: 12, fill: .surface)
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
            .rect(width: 50, height: 50, fill: .systemBlue),
            .text("Label", fontSize: 16, color: .text),
        ]),
        .roundedRect(width: 300, height: 100, radius: 12, fill: .surface),
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

// MARK: - CommandFlattener tests

@Test func flattenSimpleRect() {
    let node = ViewNode.rect(width: 100, height: 50, fill: .systemBlue)
    let layoutResult = Layout.layout(node, in: LayoutFrame(x: 10, y: 20, width: 400, height: 300))
    let commands = CommandFlattener.flatten(layoutResult)
    #expect(commands.count == 1)
    #expect(commands[0].x == 10)
    #expect(commands[0].y == 20)
    #expect(commands[0].kind == .rect(color: .systemBlue))
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
        .rect(width: 100, height: 40, fill: .systemRed),
        .roundedRect(width: 200, height: 60, radius: 8, fill: .systemGreen),
    ])
    let layoutResult = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 400, height: 300))
    let commands = CommandFlattener.flatten(layoutResult)
    #expect(commands.count == 2)
    #expect(commands[0].kind == .rect(color: .systemRed))
    #expect(commands[1].kind == .roundedRect(radius: 8, color: .systemGreen))
}
