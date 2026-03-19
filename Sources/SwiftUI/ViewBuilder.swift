@resultBuilder
public struct ViewBuilder {
    // A block component is always [ViewNode] — a flat list of nodes.
    public static func buildBlock(_ components: [ViewNode]...) -> [ViewNode] {
        components.flatMap { $0 }
    }

    // A single ViewNode expression → wrap in array.
    public static func buildExpression(_ expression: ViewNode) -> [ViewNode] {
        [expression]
    }

    // An array of ViewNodes (from ForEach) → pass through.
    public static func buildExpression(_ expression: [ViewNode]) -> [ViewNode] {
        expression
    }

    // if let / if without else
    public static func buildOptional(_ component: [ViewNode]?) -> [ViewNode] {
        component ?? []
    }

    // if/else — true branch
    public static func buildEither(first component: [ViewNode]) -> [ViewNode] {
        component
    }

    // if/else — false branch
    public static func buildEither(second component: [ViewNode]) -> [ViewNode] {
        component
    }

    // for...in loops
    public static func buildArray(_ components: [[ViewNode]]) -> [ViewNode] {
        components.flatMap { $0 }
    }
}

// Convenience initializers using ViewBuilder
public extension ViewNode {
    static func vstack(
        alignment: HAlignment = .center,
        spacing: Float = 8,
        @ViewBuilder content: () -> [ViewNode]
    ) -> ViewNode {
        .vstack(alignment: alignment, spacing: spacing, children: content())
    }

    static func hstack(
        alignment: VAlignment = .center,
        spacing: Float = 8,
        @ViewBuilder content: () -> [ViewNode]
    ) -> ViewNode {
        .hstack(alignment: alignment, spacing: spacing, children: content())
    }

    static func zstack(@ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        .zstack(children: content())
    }
}
