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
    /// Returns the tap ID and the onTap node's frame (for local coordinate conversion).
    public enum HitTestResult {
        case tap(id: UInt64, frame: LayoutFrame)
        case absorbed
    }

    public func hitTestTap(x: CGFloat, y: CGFloat) -> HitTestResult? {
        guard frame.contains(x: x, y: y) else { return nil }

        // Check children back-to-front
        var childAbsorbed = false
        for child in children.reversed() {
            if let hit = child.hitTestTap(x: x, y: y) {
                switch hit {
                case .tap:
                    return hit // definitive tap — propagate immediately
                case .absorbed:
                    childAbsorbed = true // something opaque was hit, but no handler yet
                }
            }
        }

        // If this node is an onTap, it provides the handler.
        // This fires even when a child was .absorbed (e.g. opaque background inside a button).
        if case .onTap(let id, _) = node {
            return .tap(id: id, frame: frame)
        }

        // A child was absorbed — propagate upward (prevents leak-through)
        if childAbsorbed {
            return .absorbed
        }

        // This node itself is opaque — absorb
        if node.isOpaqueHitTarget {
            return .absorbed
        }

        return nil
    }

    /// Find context menu items at the given point. Returns the menu items or nil.
    public func hitTestContextMenu(x: CGFloat, y: CGFloat) -> [ViewNode]? {
        guard frame.contains(x: x, y: y) else { return nil }

        // Check children first (deepest wins)
        for child in children.reversed() {
            if let items = child.hitTestContextMenu(x: x, y: y) {
                return items
            }
        }

        // If this node is a contextMenu, return its items
        if case .contextMenu(_, let menuItems) = node {
            return menuItems
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

        case .text(let content, let fontSize, _, let weight, _):
            // Measure text at natural (single-line) width first
            let natural = TextMeasurer.measure(content, fontSize: fontSize, weight: weight)
            // Wrap if text overflows the constraint width
            if natural.width > constraint.maxWidth && constraint.maxWidth > 0 && constraint.maxWidth < 10000 {
                let wrapped = TextMeasurer.measure(content, fontSize: fontSize, weight: weight, maxWidth: constraint.maxWidth)
                return MeasuredSize(width: min(wrapped.width, constraint.maxWidth), height: wrapped.height)
            }
            return MeasuredSize(width: natural.width, height: natural.height)

        case .lineLimit(_, let child):
            // .lineLimit(1) — measure child without wrapping (ignore constraint width for text)
            let unconstrained = SizeConstraint(maxWidth: CGFloat.greatestFiniteMagnitude, maxHeight: constraint.maxHeight)
            return measure(child, constraint: unconstrained)

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

        case .zstack(_, let children):
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
            // nil width = fill constraint (from maxWidth: .infinity)
            // explicit width = use that value, clamped to constraint
            // .infinity = fill constraint (direct usage)
            let fw: CGFloat
            if let w = width {
                fw = min(w, constraint.maxWidth)
            } else {
                fw = childSize.width
            }
            let fh: CGFloat
            if let h = height {
                fh = min(h, constraint.maxHeight)
            } else {
                fh = childSize.height
            }
            return MeasuredSize(width: fw, height: fh)

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

        case .scrollView(_, _, _):
            // ScrollView fills the proposed size (content scrolls within)
            return MeasuredSize(width: constraint.maxWidth, height: constraint.maxHeight)

        case .list(let children):
            return measureVStack(alignment: .leading, spacing: 0, children: children, constraint: constraint)

        case .lazyList(_, _):
            return MeasuredSize(width: constraint.maxWidth, height: constraint.maxHeight)

        case .lazyStack(let axis, _, let count, let spacing, let children):
            // Estimate total size from first child
            if let first = children.first {
                let childSize = measure(first, constraint: constraint)
                if axis == .vertical {
                    let totalH = childSize.height * CGFloat(count) + spacing * CGFloat(max(0, count - 1))
                    return MeasuredSize(width: constraint.maxWidth, height: totalH)
                } else {
                    let totalW = childSize.width * CGFloat(count) + spacing * CGFloat(max(0, count - 1))
                    return MeasuredSize(width: totalW, height: constraint.maxHeight)
                }
            }
            return MeasuredSize(width: 0, height: 0)

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

        case .rasterImage(_, let imgW, let imgH, _):
            // Aspect-fit: scale image to fit constraint while preserving ratio.
            let iw = CGFloat(imgW)
            let ih = CGFloat(imgH)
            guard iw > 0 && ih > 0 else { return MeasuredSize(width: 0, height: 0) }
            let scaleX = constraint.maxWidth / iw
            let scaleY = constraint.maxHeight / ih
            let s = min(scaleX, scaleY, 1.0) // don't upscale beyond natural size
            return MeasuredSize(width: iw * s, height: ih * s)

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

        case .tagged(_, let child), .toolbarItem(_, let child):
            return measure(child, constraint: constraint)

        case .clipped(_, let child):
            return measure(child, constraint: constraint)
        }
    }

    /// Full layout pass — returns a tree of LayoutNodes with absolute positions.
    public static func layout(_ node: ViewNode, in frame: LayoutFrame) -> LayoutNode {
        // Check layout cache — reuse previous frame's result if ViewNode + frame are identical
        if let cached = LayoutCache.shared.lookup(node, frame: frame) {
            return cached
        }

        let result = layoutInner(node, in: frame)
        LayoutCache.shared.store(node, frame: frame, result: result)
        return result
    }

    /// Inner layout implementation (called on cache miss).
    private static func layoutInner(_ node: ViewNode, in frame: LayoutFrame) -> LayoutNode {
        let constraint = SizeConstraint(maxWidth: frame.width, maxHeight: frame.height)

        switch node {
        case .vstack(let alignment, let spacing, let children):
            return layoutVStack(alignment: alignment, spacing: spacing, children: children, in: frame)

        case .hstack(let alignment, let spacing, let children):
            return layoutHStack(alignment: alignment, spacing: spacing, children: children, in: frame)

        case .zstack(let alignment, let children):
            return layoutZStack(alignment: alignment, children: children, in: frame)

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
            let h = height ?? frame.height  // nil height = fill parent
            let cx = frame.x
            let cy = frame.y
            let childFrame = LayoutFrame(x: cx, y: cy, width: min(w, frame.width), height: min(h, frame.height))
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

        case .scrollView(let axes, let children, let scrollKey):
            let scrollOffset = ScrollRegistry.shared.offset(scrollKey: scrollKey)
            let scrollsV = axes.contains(.vertical)
            let scrollsH = axes.contains(.horizontal)

            // Unbounded in scroll axes, fixed in non-scroll axes
            let contentFrameW: CGFloat = scrollsH ? .greatestFiniteMagnitude : frame.width
            let contentFrameH: CGFloat = scrollsV ? .greatestFiniteMagnitude : frame.height
            let contentFrame = LayoutFrame(
                x: frame.x - scrollOffset.x,
                y: frame.y - scrollOffset.y,
                width: contentFrameW,
                height: contentFrameH
            )

            // Layout content as VStack (vertical primary) or HStack (horizontal primary)
            let contentLayout: LayoutNode
            if scrollsV {
                contentLayout = layoutVStack(alignment: .leading, spacing: 0, children: children, in: contentFrame)
            } else {
                contentLayout = layoutHStack(alignment: .top, spacing: 0, children: children, in: contentFrame)
            }

            // Compute actual content dimensions
            var contentWidth: CGFloat = 0
            var contentHeight: CGFloat = 0
            for child in contentLayout.children {
                contentWidth = max(contentWidth, child.frame.x + child.frame.width - frame.x + scrollOffset.x)
                contentHeight = max(contentHeight, child.frame.y + child.frame.height - frame.y + scrollOffset.y)
            }

            ScrollRegistry.shared.registerFrame(frame, contentWidth: contentWidth, contentHeight: contentHeight, axes: axes, key: scrollKey)

            let clippedContent = LayoutNode(frame: frame, node: .clipped(radius: 0, child: node), children: [contentLayout])

            // Scrollbar indicators
            var overlays: [LayoutNode] = [clippedContent]
            let scrollbarWidth: CGFloat = 6

            if scrollsV && contentHeight > frame.height {
                let thumbRatio = frame.height / contentHeight
                let thumbHeight = max(frame.height * thumbRatio, 20)
                let thumbY = frame.y + (scrollOffset.y / contentHeight) * frame.height
                let thumbX = frame.x + frame.width - scrollbarWidth - 2
                let thumbNode = ViewNode.roundedRect(width: scrollbarWidth, height: thumbHeight, radius: 3, fill: Color(white: 0.0, opacity: 0.3))
                overlays.append(LayoutNode(frame: LayoutFrame(x: thumbX, y: thumbY, width: scrollbarWidth, height: thumbHeight), node: thumbNode))
            }
            if scrollsH && contentWidth > frame.width {
                let thumbRatio = frame.width / contentWidth
                let thumbW = max(frame.width * thumbRatio, 20)
                let thumbX = frame.x + (scrollOffset.x / contentWidth) * frame.width
                let thumbY = frame.y + frame.height - scrollbarWidth - 2
                let thumbNode = ViewNode.roundedRect(width: thumbW, height: scrollbarWidth, radius: 3, fill: Color(white: 0.0, opacity: 0.3))
                overlays.append(LayoutNode(frame: LayoutFrame(x: thumbX, y: thumbY, width: thumbW, height: scrollbarWidth), node: thumbNode))
            }

            if overlays.count > 1 {
                return LayoutNode(frame: frame, node: node, children: overlays)
            }
            return clippedContent

        case .list(let children):
            // Virtual list: only lay out visible rows + small buffer.
            // All rows use uniform height (measured from first row).
            let scrollKey = "list_\(Int(min(frame.x, 1e9)))_\(Int(min(frame.y, 1e9)))"
            let offset = ScrollRegistry.shared.offset(scrollKey: scrollKey).y
            let rowPadding: CGFloat = 12 // 6 top + 6 bottom

            // Measure first row to get uniform height
            let sampleChild = children.first ?? .empty
            let samplePadded = sampleChild.padding(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
            let sampleSize = measure(samplePadded, constraint: SizeConstraint(maxWidth: frame.width, maxHeight: .greatestFiniteMagnitude))
            let rowHeight = sampleSize.height
            let totalCount = children.count
            let totalContentHeight = rowHeight * CGFloat(totalCount)

            // Visible range with buffer
            let firstVisible = max(0, Int(offset / rowHeight) - 2)
            let lastVisible = min(totalCount - 1, Int((offset + frame.height) / rowHeight) + 2)

            // Only style + layout visible rows
            var visibleLayouts: [LayoutNode] = []
            for i in firstVisible...max(firstVisible, lastVisible) {
                let child = children[i]
                let padded = child.padding(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                let styled: ViewNode
                if i % 2 == 1 {
                    styled = ViewNode.zstack(children: [
                        ViewNode.rect(width: frame.width, height: nil, fill: Color(white: 0.96)),
                        padded,
                    ])
                } else {
                    styled = padded
                }
                let rowY = frame.y - offset + CGFloat(i) * rowHeight
                let rowFrame = LayoutFrame(x: frame.x, y: rowY, width: frame.width, height: rowHeight)
                visibleLayouts.append(layout(styled, in: rowFrame))
            }

            ScrollRegistry.shared.registerFrame(frame, contentWidth: frame.width, contentHeight: totalContentHeight, axes: .vertical, key: scrollKey)
            let contentNode = LayoutNode(frame: frame, node: .vstack(alignment: .leading, spacing: 0, children: []), children: visibleLayouts)
            return LayoutNode(frame: frame, node: .clipped(radius: 0, child: node), children: [contentNode])

        case .lazyList(let key, let count):
            // Lazy list: pull rows from LazyRowRegistry on demand.
            let scrollKey = "lazylist_\(key)"
            let offset = ScrollRegistry.shared.offset(scrollKey: scrollKey).y
            let rowPadding: CGFloat = 12

            // Estimate row height from first row
            let sampleNode = LazyRowRegistry.shared.row(for: key, at: 0)
            let samplePadded = sampleNode.padding(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
            let sampleSize = measure(samplePadded, constraint: SizeConstraint(maxWidth: frame.width, maxHeight: .greatestFiniteMagnitude))
            let rowHeight = max(sampleSize.height, 1)
            let totalContentHeight = rowHeight * CGFloat(count)

            let firstVisible = max(0, Int(offset / rowHeight) - 2)
            let lastVisible = min(count - 1, Int((offset + frame.height) / rowHeight) + 2)

            var visibleLayouts: [LayoutNode] = []
            if count > 0 {
                for i in firstVisible...max(firstVisible, lastVisible) {
                    let child = LazyRowRegistry.shared.row(for: key, at: i)
                    let padded = child.padding(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    let styled: ViewNode
                    if i % 2 == 1 {
                        styled = ViewNode.zstack(children: [
                            ViewNode.rect(width: frame.width, height: nil, fill: Color(white: 0.96)),
                            padded,
                        ])
                    } else {
                        styled = padded
                    }
                    let rowY = frame.y - offset + CGFloat(i) * rowHeight
                    let rowFrame = LayoutFrame(x: frame.x, y: rowY, width: frame.width, height: rowHeight)
                    visibleLayouts.append(layout(styled, in: rowFrame))
                }
                LazyRowRegistry.shared.evict(key: key, keeping: firstVisible...lastVisible)
            }

            ScrollRegistry.shared.registerFrame(frame, contentWidth: frame.width, contentHeight: totalContentHeight, axes: .vertical, key: scrollKey)
            let contentNode = LayoutNode(frame: frame, node: .vstack(alignment: .leading, spacing: 0, children: []), children: visibleLayouts)
            return LayoutNode(frame: frame, node: .clipped(radius: 0, child: node), children: [contentNode])

        case .lazyStack(let axis, _, let count, let spacing, let children):
            guard !children.isEmpty else {
                return LayoutNode(frame: frame, node: node)
            }
            let constraint = SizeConstraint(maxWidth: frame.width, maxHeight: frame.height)
            let sampleSize = measure(children[0], constraint: constraint)
            let itemSize = axis == .vertical ? sampleSize.height : sampleSize.width
            let step = max(itemSize + spacing, 1)

            let viewportSize = axis == .vertical ? frame.height : frame.width
            let firstVisible = max(0, Int(0 / step) - 1)
            let lastVisible = min(count - 1, Int(viewportSize / step) + 1)

            var visibleLayouts: [LayoutNode] = []
            for i in firstVisible...max(firstVisible, lastVisible) {
                guard i < children.count else { break }
                let childFrame: LayoutFrame
                if axis == .vertical {
                    childFrame = LayoutFrame(x: frame.x, y: frame.y + CGFloat(i) * step, width: frame.width, height: itemSize)
                } else {
                    childFrame = LayoutFrame(x: frame.x + CGFloat(i) * step, y: frame.y, width: itemSize, height: frame.height)
                }
                visibleLayouts.append(layoutInner(children[i], in: childFrame))
            }

            let totalSize = step * CGFloat(count) - spacing
            let contentFrame = axis == .vertical
                ? LayoutFrame(x: frame.x, y: frame.y, width: frame.width, height: totalSize)
                : LayoutFrame(x: frame.x, y: frame.y, width: totalSize, height: frame.height)
            let stackNode = axis == .vertical
                ? ViewNode.vstack(alignment: .leading, spacing: spacing, children: [])
                : ViewNode.hstack(alignment: .center, spacing: spacing, children: [])
            return LayoutNode(frame: frame, node: node, children: [
                LayoutNode(frame: contentFrame, node: stackNode, children: visibleLayouts)
            ])

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

        case .tagged(_, let child), .toolbarItem(_, let child):
            let childLayout = layout(child, in: frame)
            return LayoutNode(frame: frame, node: node, children: [childLayout])

        case .lineLimit(_, let child):
            // Pass through with same frame — the measure pass already handled unconstrained sizing
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
        alignment: Alignment, children: [ViewNode], in frame: LayoutFrame
    ) -> LayoutNode {
        let constraint = SizeConstraint(maxWidth: frame.width, maxHeight: frame.height)
        let layoutChildren = children.map { child -> LayoutNode in
            let size = measure(child, constraint: constraint)
            let w = min(size.width, frame.width)
            let h = min(size.height, frame.height)

            let cx: CGFloat
            switch alignment.horizontal {
            case .leading:  cx = frame.x
            case .center:   cx = frame.x + (frame.width - w) / 2
            case .trailing: cx = frame.x + frame.width - w
            }

            let cy: CGFloat
            switch alignment.vertical {
            case .top:    cy = frame.y
            case .center: cy = frame.y + (frame.height - h) / 2
            case .bottom: cy = frame.y + frame.height - h
            }

            let childFrame = LayoutFrame(
                x: cx.isFinite ? cx : frame.x,
                y: cy.isFinite ? cy : frame.y,
                width: w, height: h
            )
            return layout(child, in: childFrame)
        }
        return LayoutNode(frame: frame, node: .zstack(alignment: alignment, children: children), children: layoutChildren)
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
