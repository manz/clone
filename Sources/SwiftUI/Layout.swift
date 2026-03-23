import Foundation

/// A positioned rectangle — the result of layout.
public struct LayoutFrame: Equatable, Sendable {
    public let x: CGFloat
    public let y: CGFloat
    public let width: CGFloat
    public let height: CGFloat

    public init(x: CGFloat = 0, y: CGFloat = 0, width: CGFloat = 0, height: CGFloat = 0) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Size constraint passed down during layout.
public struct SizeConstraint: Sendable {
    public let maxWidth: CGFloat
    public let maxHeight: CGFloat

    public init(maxWidth: CGFloat, maxHeight: CGFloat) {
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
    }
}

/// Result of measuring a node — its desired size.
public struct MeasuredSize: Equatable, Sendable {
    public let width: CGFloat
    public let height: CGFloat

    public init(width: CGFloat = 0, height: CGFloat = 0) {
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

// MARK: - Hit testing

extension LayoutFrame {
    public func contains(x: CGFloat, y: CGFloat) -> Bool {
        x >= self.x && x <= self.x + width && y >= self.y && y <= self.y + height
    }
}

extension LayoutNode {
    /// Returns the deepest node whose frame contains the point, or nil.
    public func hitTest(x: CGFloat, y: CGFloat) -> LayoutNode? {
        guard frame.contains(x: x, y: y) else { return nil }
        // Check children back-to-front (last child is on top in ZStack)
        for child in children.reversed() {
            if let hit = child.hitTest(x: x, y: y) {
                return hit
            }
        }
        return self
    }

    /// Find the deepest onTap node whose frame contains the point.
    /// Walks the tree and returns the deepest `.onTap` ancestor of the hit point.
    public func hitTestTap(x: CGFloat, y: CGFloat) -> UInt64? {
        guard frame.contains(x: x, y: y) else { return nil }

        // Check children back-to-front
        for child in children.reversed() {
            if let tapId = child.hitTestTap(x: x, y: y) {
                return tapId
            }
        }

        // If this node itself is an onTap, return its ID
        if case .onTap(let id, _) = node {
            return id
        }

        return nil
    }

    /// Collect all onHover IDs whose frame contains the point.
    public func hitTestHover(x: CGFloat, y: CGFloat) -> Set<UInt64> {
        guard frame.contains(x: x, y: y) else { return [] }
        var ids = Set<UInt64>()
        if case .onHover(let id, _) = node {
            ids.insert(id)
        }
        for child in children {
            ids.formUnion(child.hitTestHover(x: x, y: y))
        }
        return ids
    }
}

// MARK: - Layout engine

public enum Layout {

    /// Measure the desired size of a ViewNode given constraints.
    public static func measure(_ node: ViewNode, constraint: SizeConstraint) -> MeasuredSize {
        switch node {
        case .empty:
            return MeasuredSize()

        case .text(let content, let fontSize, _, let weight):
            let size = TextMeasurer.measure(content, fontSize: fontSize, weight: weight)
            return MeasuredSize(width: size.width, height: size.height)

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

        case .shadow(_, _, _, _, _, let child):
            return measure(child, constraint: constraint)

        case .onTap(_, let child):
            return measure(child, constraint: constraint)

        case .onHover(_, let child):
            return measure(child, constraint: constraint)

        case .geometryReader:
            // GeometryReader fills the proposed space (like SwiftUI)
            return MeasuredSize(width: constraint.maxWidth, height: constraint.maxHeight)

        case .scrollView(_, _):
            // ScrollView fills the proposed size (content scrolls within)
            return MeasuredSize(width: constraint.maxWidth, height: constraint.maxHeight)

        case .list(let children):
            return measureVStack(alignment: .leading, spacing: 0, children: children, constraint: constraint)

        case .grid(let columns, let spacing, let children):
            let colCount = Self.gridColumnCount(columns, availableWidth: constraint.maxWidth, spacing: spacing)
            let rowCount = (children.count + colCount - 1) / colCount
            let colWidth = (constraint.maxWidth - spacing * CGFloat(colCount - 1)) / CGFloat(colCount)
            // Measure first child to estimate row height
            let rowHeight: CGFloat
            if let first = children.first {
                let childSize = measure(first, constraint: SizeConstraint(maxWidth: colWidth, maxHeight: constraint.maxHeight))
                rowHeight = childSize.height
            } else {
                rowHeight = 0
            }
            let totalHeight = CGFloat(rowCount) * rowHeight + CGFloat(max(0, rowCount - 1)) * spacing
            return MeasuredSize(width: constraint.maxWidth, height: totalHeight)

        case .image(_, let width, let height, _):
            // SF Symbols default to ~17pt (body font size) when no explicit size
            let defaultSize: CGFloat = 17
            return MeasuredSize(
                width: width ?? defaultSize,
                height: height ?? defaultSize
            )

        case .toggle(_, let label):
            let labelSize = measure(label, constraint: constraint)
            return MeasuredSize(width: labelSize.width + 60, height: max(labelSize.height, 30))

        case .slider(_, _, _):
            return MeasuredSize(width: constraint.maxWidth, height: 30)

        case .picker(_, let label, _):
            let labelSize = measure(label, constraint: constraint)
            return MeasuredSize(width: labelSize.width + 100, height: max(labelSize.height, 30))

        case .textField(let placeholder, _, _):
            let charWidth: CGFloat = 14 * 0.6
            let width = charWidth * CGFloat(placeholder.count) + 16
            return MeasuredSize(width: max(width, 200), height: 30)

        case .navigationStack(let children):
            return measureVStack(alignment: .leading, spacing: 0, children: children, constraint: constraint)

        case .menu(let label, _):
            // Collapsed state: measure the label text only
            let charWidth: CGFloat = 14 * 0.6
            return MeasuredSize(width: charWidth * CGFloat(label.count), height: 14)

        case .contextMenu(let child, _):
            // Menu invisible until triggered — measure the child only
            return measure(child, constraint: constraint)

        case .clipped(_, let child):
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
            let h = height ?? frame.height  // nil height = fill parent (Apple behavior)
            // Center horizontally if width is explicit, top-align vertically
            let cx = width != nil ? frame.x + (frame.width - w) / 2 : frame.x
            let cy = frame.y  // Top-aligned — Apple's .frame() doesn't center vertically
            let childFrame = LayoutFrame(x: cx, y: cy, width: w, height: h)
            let childLayout = layout(child, in: childFrame)
            return LayoutNode(frame: childFrame, node: node, children: [childLayout])

        case .opacity(_, let child):
            let childLayout = layout(child, in: frame)
            return LayoutNode(frame: frame, node: node, children: [childLayout])

        case .shadow(_, _, _, _, _, let child):
            let childSize = measure(child, constraint: constraint)
            let childFrame = LayoutFrame(x: frame.x, y: frame.y, width: childSize.width, height: childSize.height)
            let childLayout = layout(child, in: childFrame)
            return LayoutNode(frame: childFrame, node: node, children: [childLayout])

        case .onTap(_, let child):
            let childLayout = layout(child, in: frame)
            return LayoutNode(frame: frame, node: node, children: [childLayout])

        case .onHover(_, let child):
            let childLayout = layout(child, in: frame)
            return LayoutNode(frame: frame, node: node, children: [childLayout])

        case .geometryReader(let id):
            let proxy = GeometryProxy(
                size: CGSize(width: frame.width, height: frame.height),
                frame: frame
            )
            let resolved = GeometryReaderRegistry.shared.resolve(id: id, proxy: proxy)
            let childLayout = layout(resolved, in: frame)
            return LayoutNode(frame: frame, node: node, children: [childLayout])

        case .scrollView(let axis, let children):
            // Layout children with unbounded constraint in the scroll axis,
            // then wrap in a clipped node so overflow is hidden.
            let contentLayout: LayoutNode
            if axis == .vertical {
                // Unbounded height for vertical scrolling
                let contentFrame = LayoutFrame(x: frame.x, y: frame.y, width: frame.width, height: .greatestFiniteMagnitude)
                contentLayout = layoutVStack(alignment: .leading, spacing: 0, children: children, in: contentFrame)
            } else {
                let contentFrame = LayoutFrame(x: frame.x, y: frame.y, width: .greatestFiniteMagnitude, height: frame.height)
                contentLayout = layoutHStack(alignment: .top, spacing: 0, children: children, in: contentFrame)
            }
            // Clip to the ScrollView's frame
            return LayoutNode(frame: frame, node: .clipped(radius: 0, child: node), children: [contentLayout])

        case .list(let children):
            return layoutVStack(alignment: .leading, spacing: 0, children: children, in: frame)

        case .grid(let columns, let spacing, let children):
            return layoutGrid(columns: columns, spacing: spacing, children: children, in: frame)

        case .navigationStack(let children):
            return layoutVStack(alignment: .leading, spacing: 0, children: children, in: frame)

        case .toggle(_, let label):
            let labelLayout = layout(label, in: frame)
            return LayoutNode(frame: frame, node: node, children: [labelLayout])

        case .menu(let label, _):
            // Collapsed: layout as a text label
            let labelNode = ViewNode.text(label, fontSize: 14, color: .primary)
            let labelLayout = layout(labelNode, in: frame)
            return LayoutNode(frame: frame, node: node, children: [labelLayout])

        case .contextMenu(let child, _):
            // Layout the child; menu items are not laid out until triggered
            let childLayout = layout(child, in: frame)
            return LayoutNode(frame: frame, node: node, children: [childLayout])

        case .clipped(_, let child):
            let childLayout = layout(child, in: frame)
            return LayoutNode(frame: frame, node: node, children: [childLayout])

        case .textField(_, _, let registryId):
            let size = measure(node, constraint: constraint)
            let leafFrame = LayoutFrame(x: frame.x, y: frame.y, width: size.width, height: size.height)
            if registryId > 0 {
                TextFieldRegistry.shared.setFrame(id: registryId, frame: leafFrame)
            }
            return LayoutNode(frame: leafFrame, node: node)

        default:
            // Leaf nodes: text, rect, roundedRect, blur, spacer, empty, image, slider, picker
            let size = measure(node, constraint: constraint)
            let leafFrame = LayoutFrame(x: frame.x, y: frame.y, width: size.width, height: size.height)
            return LayoutNode(frame: leafFrame, node: node)
        }
    }

    // MARK: - VStack

    private static func measureVStack(
        alignment: HAlignment, spacing: CGFloat,
        children: [ViewNode], constraint: SizeConstraint
    ) -> MeasuredSize {
        var totalHeight: CGFloat = 0
        var maxWidth: CGFloat = 0
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
        alignment: HAlignment, spacing: CGFloat,
        children: [ViewNode], in frame: LayoutFrame
    ) -> LayoutNode {
        let constraint = SizeConstraint(maxWidth: frame.width, maxHeight: frame.height)

        // Measure non-spacer children, reducing remaining height for each
        var fixedHeight: CGFloat = 0
        var spacerCount = 0
        var childSizes: [MeasuredSize] = []
        var remainingHeight = frame.height

        for (i, child) in children.enumerated() {
            if i > 0 { remainingHeight -= spacing }
            if case .spacer = child {
                spacerCount += 1
                childSizes.append(MeasuredSize())
            } else {
                let childConstraint = SizeConstraint(maxWidth: constraint.maxWidth, maxHeight: max(0, remainingHeight))
                let size = measure(child, constraint: childConstraint)
                childSizes.append(size)
                fixedHeight += size.height
                remainingHeight -= size.height
            }
            if i > 0 { fixedHeight += spacing }
        }

        let spacerHeight = spacerCount > 0
            ? max(0, (frame.height - fixedHeight) / CGFloat(spacerCount))
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
                let x: CGFloat
                switch alignment {
                case .leading: x = frame.x
                case .center:
                    let w = min(size.width, frame.width)
                    x = frame.x + (frame.width - w) / 2
                case .trailing: x = frame.x + frame.width - size.width
                }
                let childWidth = min(size.width, frame.width)
                let childFrame = LayoutFrame(x: x.isFinite ? x : frame.x, y: y, width: childWidth, height: size.height)
                layoutChildren.append(layout(child, in: childFrame))
                y += size.height
            }
        }

        return LayoutNode(frame: frame, node: .vstack(alignment: alignment, spacing: spacing, children: children), children: layoutChildren)
    }

    // MARK: - HStack

    private static func measureHStack(
        alignment: VAlignment, spacing: CGFloat,
        children: [ViewNode], constraint: SizeConstraint
    ) -> MeasuredSize {
        var totalWidth: CGFloat = 0
        var maxHeight: CGFloat = 0
        var spacerCount = 0
        var remainingWidth = constraint.maxWidth

        for (i, child) in children.enumerated() {
            if i > 0 { remainingWidth -= spacing }
            if case .spacer = child {
                spacerCount += 1
                continue
            }
            let childConstraint = SizeConstraint(maxWidth: max(0, remainingWidth), maxHeight: constraint.maxHeight)
            let childSize = measure(child, constraint: childConstraint)
            maxHeight = max(maxHeight, childSize.height)
            totalWidth += childSize.width
            remainingWidth -= childSize.width
            if i > 0 { totalWidth += spacing }
        }

        if spacerCount > 0 {
            totalWidth = constraint.maxWidth
        }

        return MeasuredSize(width: totalWidth, height: maxHeight)
    }

    private static func layoutHStack(
        alignment: VAlignment, spacing: CGFloat,
        children: [ViewNode], in frame: LayoutFrame
    ) -> LayoutNode {
        var fixedWidth: CGFloat = 0
        var spacerCount = 0
        var childSizes: [MeasuredSize] = []
        var remainingWidth = frame.width

        for (i, child) in children.enumerated() {
            if i > 0 { remainingWidth -= spacing }
            if case .spacer = child {
                spacerCount += 1
                childSizes.append(MeasuredSize())
            } else {
                let childConstraint = SizeConstraint(maxWidth: max(0, remainingWidth), maxHeight: frame.height)
                let size = measure(child, constraint: childConstraint)
                childSizes.append(size)
                fixedWidth += size.width
                remainingWidth -= size.width
            }
            if i > 0 { fixedWidth += spacing }
        }

        let spacerWidth = spacerCount > 0
            ? max(0, (frame.width - fixedWidth) / CGFloat(spacerCount))
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
                let y: CGFloat
                switch alignment {
                case .top: y = frame.y
                case .center:
                    let h = min(size.height, frame.height)
                    y = frame.y + (frame.height - h) / 2
                case .bottom: y = frame.y + frame.height - size.height
                }
                let childHeight = min(size.height, frame.height)
                let childFrame = LayoutFrame(x: x, y: y.isFinite ? y : frame.y, width: size.width, height: childHeight)
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
        var maxWidth: CGFloat = 0
        var maxHeight: CGFloat = 0

        for child in children {
            // Skip nil-sized rects — they're flexible backgrounds that should
            // match sibling size, not inflate the ZStack to fill the constraint.
            if case .rect(let w, let h, _) = child, w == nil || h == nil { continue }
            if case .roundedRect(let w, let h, _, _) = child, w == nil || h == nil { continue }
            let size = measure(child, constraint: constraint)
            maxWidth = max(maxWidth, size.width)
            maxHeight = max(maxHeight, size.height)
        }

        // If no sized children, fall back to constraint
        if maxWidth == 0 { maxWidth = constraint.maxWidth }
        if maxHeight == 0 { maxHeight = constraint.maxHeight }

        return MeasuredSize(width: maxWidth, height: maxHeight)
    }

    private static func layoutZStack(
        children: [ViewNode], in frame: LayoutFrame
    ) -> LayoutNode {
        let constraint = SizeConstraint(maxWidth: frame.width, maxHeight: frame.height)
        let layoutChildren = children.map { child -> LayoutNode in
            let size = measure(child, constraint: constraint)
            let w = min(size.width, frame.width)
            let h = min(size.height, frame.height)
            let cx = frame.x + (frame.width - w) / 2
            let cy = frame.y + (frame.height - h) / 2
            let childFrame = LayoutFrame(x: cx.isFinite ? cx : frame.x, y: cy.isFinite ? cy : frame.y, width: w, height: h)
            return layout(child, in: childFrame)
        }
        return LayoutNode(frame: frame, node: .zstack(children: children), children: layoutChildren)
    }

    // MARK: - Grid

    /// Compute column count for adaptive grids.
    static func gridColumnCount(_ columns: [GridColumnSpec], availableWidth: CGFloat, spacing: CGFloat) -> Int {
        guard let first = columns.first else { return 1 }
        switch first.kind {
        case .adaptive(let min, _):
            // How many columns of minWidth fit?
            let count = max(1, Int((availableWidth + spacing) / (min + spacing)))
            return count
        case .fixed:
            return columns.count
        case .flexible:
            return columns.count
        }
    }

    /// Layout children in a grid.
    private static func layoutGrid(
        columns: [GridColumnSpec], spacing: CGFloat, children: [ViewNode], in frame: LayoutFrame
    ) -> LayoutNode {
        let colCount = gridColumnCount(columns, availableWidth: frame.width, spacing: spacing)
        let colWidth = (frame.width - spacing * CGFloat(max(0, colCount - 1))) / CGFloat(colCount)

        var layoutChildren: [LayoutNode] = []
        var y = frame.y

        // Process children in rows
        var i = 0
        while i < children.count {
            var rowHeight: CGFloat = 0
            var rowLayouts: [LayoutNode] = []

            for col in 0..<colCount {
                guard i < children.count else { break }
                let child = children[i]
                let x = frame.x + CGFloat(col) * (colWidth + spacing)
                let childConstraint = SizeConstraint(maxWidth: colWidth, maxHeight: frame.height - (y - frame.y))
                let childSize = measure(child, constraint: childConstraint)
                let childFrame = LayoutFrame(x: x, y: y, width: colWidth, height: childSize.height)
                rowLayouts.append(layout(child, in: childFrame))
                rowHeight = max(rowHeight, childSize.height)
                i += 1
            }

            layoutChildren.append(contentsOf: rowLayouts)
            y += rowHeight + spacing
        }

        return LayoutNode(
            frame: frame,
            node: .grid(columns: columns, spacing: spacing, children: children),
            children: layoutChildren
        )
    }
}
