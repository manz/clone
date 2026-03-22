import Foundation

/// A specification for a grid column/row.
public struct GridItem: Sendable {
    public enum Size: Sendable {
        case fixed(CGFloat)
        case _flexible(minimum: CGFloat, maximum: CGFloat)
        case _adaptive(minimum: CGFloat, maximum: CGFloat)

        /// `.flexible(minimum:maximum:)` — matches Apple's SwiftUI.
        public static func flexible(minimum: CGFloat = 10, maximum: CGFloat = .infinity) -> Size {
            ._flexible(minimum: minimum, maximum: maximum)
        }

        /// `.adaptive(minimum:maximum:)` — matches Apple's SwiftUI.
        public static func adaptive(minimum: CGFloat, maximum: CGFloat = .infinity) -> Size {
            ._adaptive(minimum: minimum, maximum: maximum)
        }
    }

    public let size: Size
    public let spacing: CGFloat?
    public let alignment: HAlignment?

    public init(_ size: Size = .flexible(minimum: 10, maximum: .infinity), spacing: CGFloat? = nil, alignment: HAlignment? = nil) {
        self.size = size
        self.spacing = spacing
        self.alignment = alignment
    }

    /// Convenience for `.fixed(size)`.
    public static func fixed(_ size: CGFloat) -> GridItem {
        GridItem(.fixed(size))
    }

    /// Convenience for `.flexible()`.
    public static func flexible(minimum: CGFloat = 10, maximum: CGFloat = .infinity) -> GridItem {
        GridItem(.flexible(minimum: minimum, maximum: maximum))
    }

    /// Convenience for `.adaptive(minimum:)`.
    public static func adaptive(minimum: CGFloat, maximum: CGFloat = .infinity) -> GridItem {
        GridItem(.adaptive(minimum: minimum, maximum: maximum))
    }
}

/// A container that arranges its children in a vertically scrolling grid.
/// On Clone, renders as a simple VStack of HStacks (no lazy loading).
public struct LazyVGrid: _PrimitiveView {
    let columns: [GridItem]
    let alignment: HAlignment
    let spacing: CGFloat
    let children: [ViewNode]

    public init(
        columns: [GridItem],
        alignment: HAlignment = .center,
        spacing: CGFloat? = nil,
        pinnedViews: Set<PinnedScrollableViews> = [],
        @ViewBuilder content: () -> some View
    ) {
        self.columns = columns
        self.alignment = alignment
        self.spacing = spacing ?? 8
        self.children = _flattenToNodes(content())
    }

    public var _nodeRepresentation: ViewNode {
        let specs = columns.map { col -> GridColumnSpec in
            switch col.size {
            case .fixed(let size):
                return GridColumnSpec(.fixed(size))
            case ._flexible(let min, let max):
                return GridColumnSpec(.flexible(min: min, max: max))
            case ._adaptive(let min, let max):
                return GridColumnSpec(.adaptive(min: min, max: max))
            }
        }
        return .grid(columns: specs, spacing: spacing, children: children)
    }
}

/// A container that arranges its children in a horizontally scrolling grid.
/// On Clone, renders as a simple HStack of VStacks (no lazy loading).
public struct LazyHGrid: _PrimitiveView {
    let rows: [GridItem]
    let alignment: VAlignment
    let spacing: CGFloat
    let children: [ViewNode]

    public init(
        rows: [GridItem],
        alignment: VAlignment = .center,
        spacing: CGFloat? = nil,
        pinnedViews: Set<PinnedScrollableViews> = [],
        @ViewBuilder content: () -> some View
    ) {
        self.rows = rows
        self.alignment = alignment
        self.spacing = spacing ?? 8
        self.children = _flattenToNodes(content())
    }

    public var _nodeRepresentation: ViewNode {
        let rowCount = max(rows.count, 1)
        var columns: [[ViewNode]] = []
        var currentCol: [ViewNode] = []

        for child in children {
            currentCol.append(child)
            if currentCol.count >= rowCount {
                columns.append(currentCol)
                currentCol = []
            }
        }
        if !currentCol.isEmpty {
            columns.append(currentCol)
        }

        let colNodes: [ViewNode] = columns.map { col in
            .vstack(alignment: .leading, spacing: spacing, children: col)
        }

        return .hstack(alignment: alignment, spacing: spacing, children: colNodes)
    }
}

/// Pinned views for lazy grids/stacks.
public enum PinnedScrollableViews: Hashable, Sendable {
    case sectionHeaders
    case sectionFooters
}
