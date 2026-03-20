import Foundation

/// A specification for a grid column/row.
public struct GridItem: Sendable {
    public enum Size: Sendable {
        case fixed(CGFloat)
        case flexible(minimum: CGFloat, maximum: CGFloat)
        case adaptive(minimum: CGFloat, maximum: CGFloat)

        /// `.flexible()` with defaults — matches Apple's SwiftUI.
        public static func flexible() -> Size {
            .flexible(minimum: 10, maximum: .infinity)
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
public struct LazyVGrid: View {
    let columns: [GridItem]
    let alignment: HAlignment
    let spacing: CGFloat
    let children: [ViewNode]

    public init(
        columns: [GridItem],
        alignment: HAlignment = .center,
        spacing: CGFloat? = nil,
        pinnedViews: Set<PinnedScrollableViews> = [],
        @ViewBuilder content: () -> [ViewNode]
    ) {
        self.columns = columns
        self.alignment = alignment
        self.spacing = spacing ?? 8
        self.children = content()
    }

    public var body: ViewNode {
        let columnCount = max(columns.count, 1)
        var rows: [[ViewNode]] = []
        var currentRow: [ViewNode] = []

        for child in children {
            currentRow.append(child)
            if currentRow.count >= columnCount {
                rows.append(currentRow)
                currentRow = []
            }
        }
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        let rowNodes: [ViewNode] = rows.map { row in
            .hstack(alignment: .top, spacing: spacing, children: row)
        }

        return .vstack(alignment: alignment, spacing: spacing, children: rowNodes)
    }
}

/// A container that arranges its children in a horizontally scrolling grid.
/// On Clone, renders as a simple HStack of VStacks (no lazy loading).
public struct LazyHGrid: View {
    let rows: [GridItem]
    let alignment: VAlignment
    let spacing: CGFloat
    let children: [ViewNode]

    public init(
        rows: [GridItem],
        alignment: VAlignment = .center,
        spacing: CGFloat? = nil,
        pinnedViews: Set<PinnedScrollableViews> = [],
        @ViewBuilder content: () -> [ViewNode]
    ) {
        self.rows = rows
        self.alignment = alignment
        self.spacing = spacing ?? 8
        self.children = content()
    }

    public var body: ViewNode {
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
