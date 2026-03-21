import Foundation

@resultBuilder
public struct ViewBuilder {
    // Empty block — for `#if ... #endif` that produces nothing on current platform.
    public static func buildBlock() -> [ViewNode] { [] }

    // A block component is always [ViewNode] — a flat list of nodes.
    public static func buildBlock(_ components: [ViewNode]...) -> [ViewNode] {
        components.flatMap { $0 }
    }

    // A single ViewNode expression → wrap in array.
    public static func buildExpression(_ expression: ViewNode) -> [ViewNode] {
        [expression]
    }

    // Any View expression → resolve body to ViewNode.
    public static func buildExpression<V: View>(_ expression: V) -> [ViewNode] {
        [_resolve(expression)]
    }

    // An array of ViewNodes → pass through.
    public static func buildExpression(_ expression: [ViewNode]) -> [ViewNode] {
        expression
    }

    // ForEach expression → extract its nodes.
    public static func buildExpression<D>(_ expression: ForEach<D>) -> [ViewNode] {
        expression.nodes
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

    // Never support — allows Body == Never with @ViewBuilder on View protocol
    public static func buildExpression(_ expression: Never) -> Never {}
    public static func buildBlock(_ n: Never) -> Never {}
}

// Convenience initializers using ViewBuilder
public extension ViewNode {
    static func vstack(
        alignment: HAlignment = .center,
        spacing: CGFloat = 8,
        @ViewBuilder content: () -> [ViewNode]
    ) -> ViewNode {
        .vstack(alignment: alignment, spacing: spacing, children: content())
    }

    static func hstack(
        alignment: VAlignment = .center,
        spacing: CGFloat = 8,
        @ViewBuilder content: () -> [ViewNode]
    ) -> ViewNode {
        .hstack(alignment: alignment, spacing: spacing, children: content())
    }

    static func zstack(@ViewBuilder content: () -> [ViewNode]) -> ViewNode {
        .zstack(children: content())
    }
}
