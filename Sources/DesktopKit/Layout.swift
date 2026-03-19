import Foundation

/// A positioned rectangle — the result of layout.
public struct LayoutFrame: Equatable, Sendable {
    public let x: Float
    public let y: Float
    public let width: Float
    public let height: Float

    public init(x: Float = 0, y: Float = 0, width: Float = 0, height: Float = 0) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Size constraint passed down during layout.
public struct SizeConstraint: Sendable {
    public let maxWidth: Float
    public let maxHeight: Float

    public init(maxWidth: Float, maxHeight: Float) {
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
    }
}

/// Result of measuring a node — its desired size.
public struct MeasuredSize: Equatable, Sendable {
    public let width: Float
    public let height: Float

    public init(width: Float = 0, height: Float = 0) {
        self.width = width
        self.height = height
    }
}

/// Laid-out node: frame + children
public struct LayoutNode: Equatable, Sendable {
    public let frame: LayoutFrame
    public let node: ViewNode
    public let children: [LayoutNode]

    public init(frame: LayoutFrame, node: ViewNode, children: [LayoutNode] = []) {
        self.frame = frame
        self.node = node
        self.children = children
    }
}

// MARK: - Layout engine

public enum Layout {

    /// Measure the desired size of a ViewNode given constraints.
    public static func measure(_ node: ViewNode, constraint: SizeConstraint) -> MeasuredSize {
        switch node {
        case .empty:
            return MeasuredSize()

        case .text(let content, let fontSize, _):
            // Approximate: 0.6 * fontSize per character width, fontSize for height
            let charWidth = fontSize * 0.6
            let width = charWidth * Float(content.count)
            return MeasuredSize(width: width, height: fontSize)

        case .rect(let width, let height, _):
            return MeasuredSize(
                width: width ?? constraint.maxWidth,
                height: height ?? constraint.maxHeight
            )

        case .roundedRect(let width, let height, _, _):
            return MeasuredSize(
                width: width ?? constraint.maxWidth,
                height: height ?? constraint.maxHeight
            )

        case .blur:
            return MeasuredSize(width: constraint.maxWidth, height: constraint.maxHeight)

        case .spacer(let minLength):
            return MeasuredSize(width: minLength, height: minLength)

        case .vstack(let alignment, let spacing, let children):
            return measureVStack(alignment: alignment, spacing: spacing, children: children, constraint: constraint)

        case .hstack(let alignment, let spacing, let children):
            return measureHStack(alignment: alignment, spacing: spacing, children: children, constraint: constraint)

        case .zstack(let children):
            return measureZStack(children: children, constraint: constraint)

        case .padding(let insets, let child):
            let inner = SizeConstraint(
                maxWidth: constraint.maxWidth - insets.leading - insets.trailing,
                maxHeight: constraint.maxHeight - insets.top - insets.bottom
            )
            let childSize = measure(child, constraint: inner)
            return MeasuredSize(
                width: childSize.width + insets.leading + insets.trailing,
                height: childSize.height + insets.top + insets.bottom
            )

        case .frame(let width, let height, let child):
            let childSize = measure(child, constraint: constraint)
            return MeasuredSize(
                width: width ?? childSize.width,
                height: height ?? childSize.height
            )

        case .opacity(_, let child):
            return measure(child, constraint: constraint)

        case .onTap(_, let child):
            return measure(child, constraint: constraint)
        }
    }

    /// Full layout pass — returns a tree of LayoutNodes with absolute positions.
    public static func layout(_ node: ViewNode, in frame: LayoutFrame) -> LayoutNode {
        let constraint = SizeConstraint(maxWidth: frame.width, maxHeight: frame.height)

        switch node {
        case .vstack(let alignment, let spacing, let children):
            return layoutVStack(alignment: alignment, spacing: spacing, children: children, in: frame)

        case .hstack(let alignment, let spacing, let children):
            return layoutHStack(alignment: alignment, spacing: spacing, children: children, in: frame)

        case .zstack(let children):
            return layoutZStack(children: children, in: frame)

        case .padding(let insets, let child):
            let innerFrame = LayoutFrame(
                x: frame.x + insets.leading,
                y: frame.y + insets.top,
                width: frame.width - insets.leading - insets.trailing,
                height: frame.height - insets.top - insets.bottom
            )
            let childLayout = layout(child, in: innerFrame)
            return LayoutNode(frame: frame, node: node, children: [childLayout])

        case .frame(let width, let height, let child):
            let childSize = measure(child, constraint: constraint)
            let w = width ?? childSize.width
            let h = height ?? childSize.height
            let childFrame = LayoutFrame(x: frame.x, y: frame.y, width: w, height: h)
            let childLayout = layout(child, in: childFrame)
            return LayoutNode(frame: childFrame, node: node, children: [childLayout])

        case .opacity(_, let child):
            let childLayout = layout(child, in: frame)
            return LayoutNode(frame: frame, node: node, children: [childLayout])

        case .onTap(_, let child):
            let childLayout = layout(child, in: frame)
            return LayoutNode(frame: frame, node: node, children: [childLayout])

        default:
            // Leaf nodes: text, rect, roundedRect, blur, spacer, empty
            let size = measure(node, constraint: constraint)
            let leafFrame = LayoutFrame(x: frame.x, y: frame.y, width: size.width, height: size.height)
            return LayoutNode(frame: leafFrame, node: node)
        }
    }

    // MARK: - VStack

    private static func measureVStack(
        alignment: HAlignment, spacing: Float,
        children: [ViewNode], constraint: SizeConstraint
    ) -> MeasuredSize {
        var totalHeight: Float = 0
        var maxWidth: Float = 0
        var spacerCount = 0

        for (i, child) in children.enumerated() {
            if case .spacer = child {
                spacerCount += 1
                continue
            }
            let childSize = measure(child, constraint: constraint)
            maxWidth = max(maxWidth, childSize.width)
            totalHeight += childSize.height
            if i > 0 { totalHeight += spacing }
        }

        // Spacers expand to fill
        if spacerCount > 0 {
            totalHeight = constraint.maxHeight
        }

        return MeasuredSize(width: maxWidth, height: totalHeight)
    }

    private static func layoutVStack(
        alignment: HAlignment, spacing: Float,
        children: [ViewNode], in frame: LayoutFrame
    ) -> LayoutNode {
        let constraint = SizeConstraint(maxWidth: frame.width, maxHeight: frame.height)

        // Measure non-spacer children
        var fixedHeight: Float = 0
        var spacerCount = 0
        var childSizes: [MeasuredSize] = []

        for (i, child) in children.enumerated() {
            if case .spacer = child {
                spacerCount += 1
                childSizes.append(MeasuredSize())
            } else {
                let size = measure(child, constraint: constraint)
                childSizes.append(size)
                fixedHeight += size.height
            }
            if i > 0 { fixedHeight += spacing }
        }

        let spacerHeight = spacerCount > 0
            ? max(0, (frame.height - fixedHeight) / Float(spacerCount))
            : 0

        var y = frame.y
        var layoutChildren: [LayoutNode] = []

        for (i, child) in children.enumerated() {
            if i > 0 { y += spacing }

            if case .spacer = child {
                let spacerFrame = LayoutFrame(x: frame.x, y: y, width: frame.width, height: spacerHeight)
                layoutChildren.append(LayoutNode(frame: spacerFrame, node: child))
                y += spacerHeight
            } else {
                let size = childSizes[i]
                let x: Float
                switch alignment {
                case .leading: x = frame.x
                case .center: x = frame.x + (frame.width - size.width) / 2
                case .trailing: x = frame.x + frame.width - size.width
                }
                let childFrame = LayoutFrame(x: x, y: y, width: size.width, height: size.height)
                layoutChildren.append(layout(child, in: childFrame))
                y += size.height
            }
        }

        return LayoutNode(frame: frame, node: .vstack(alignment: alignment, spacing: spacing, children: children), children: layoutChildren)
    }

    // MARK: - HStack

    private static func measureHStack(
        alignment: VAlignment, spacing: Float,
        children: [ViewNode], constraint: SizeConstraint
    ) -> MeasuredSize {
        var totalWidth: Float = 0
        var maxHeight: Float = 0
        var spacerCount = 0

        for (i, child) in children.enumerated() {
            if case .spacer = child {
                spacerCount += 1
                continue
            }
            let childSize = measure(child, constraint: constraint)
            maxHeight = max(maxHeight, childSize.height)
            totalWidth += childSize.width
            if i > 0 { totalWidth += spacing }
        }

        if spacerCount > 0 {
            totalWidth = constraint.maxWidth
        }

        return MeasuredSize(width: totalWidth, height: maxHeight)
    }

    private static func layoutHStack(
        alignment: VAlignment, spacing: Float,
        children: [ViewNode], in frame: LayoutFrame
    ) -> LayoutNode {
        let constraint = SizeConstraint(maxWidth: frame.width, maxHeight: frame.height)

        var fixedWidth: Float = 0
        var spacerCount = 0
        var childSizes: [MeasuredSize] = []

        for (i, child) in children.enumerated() {
            if case .spacer = child {
                spacerCount += 1
                childSizes.append(MeasuredSize())
            } else {
                let size = measure(child, constraint: constraint)
                childSizes.append(size)
                fixedWidth += size.width
            }
            if i > 0 { fixedWidth += spacing }
        }

        let spacerWidth = spacerCount > 0
            ? max(0, (frame.width - fixedWidth) / Float(spacerCount))
            : 0

        var x = frame.x
        var layoutChildren: [LayoutNode] = []

        for (i, child) in children.enumerated() {
            if i > 0 { x += spacing }

            if case .spacer = child {
                let spacerFrame = LayoutFrame(x: x, y: frame.y, width: spacerWidth, height: frame.height)
                layoutChildren.append(LayoutNode(frame: spacerFrame, node: child))
                x += spacerWidth
            } else {
                let size = childSizes[i]
                let y: Float
                switch alignment {
                case .top: y = frame.y
                case .center: y = frame.y + (frame.height - size.height) / 2
                case .bottom: y = frame.y + frame.height - size.height
                }
                let childFrame = LayoutFrame(x: x, y: y, width: size.width, height: size.height)
                layoutChildren.append(layout(child, in: childFrame))
                x += size.width
            }
        }

        return LayoutNode(frame: frame, node: .hstack(alignment: alignment, spacing: spacing, children: children), children: layoutChildren)
    }

    // MARK: - ZStack

    private static func measureZStack(
        children: [ViewNode], constraint: SizeConstraint
    ) -> MeasuredSize {
        var maxWidth: Float = 0
        var maxHeight: Float = 0

        for child in children {
            let size = measure(child, constraint: constraint)
            maxWidth = max(maxWidth, size.width)
            maxHeight = max(maxHeight, size.height)
        }

        return MeasuredSize(width: maxWidth, height: maxHeight)
    }

    private static func layoutZStack(
        children: [ViewNode], in frame: LayoutFrame
    ) -> LayoutNode {
        let layoutChildren = children.map { child in
            layout(child, in: frame)
        }
        return LayoutNode(frame: frame, node: .zstack(children: children), children: layoutChildren)
    }
}
