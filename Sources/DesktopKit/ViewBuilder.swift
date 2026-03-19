@resultBuilder
public struct ViewBuilder {
    public static func buildBlock(_ components: ViewNode...) -> [ViewNode] {
        components
    }

    public static func buildExpression(_ expression: ViewNode) -> ViewNode {
        expression
    }

    public static func buildOptional(_ component: [ViewNode]?) -> ViewNode {
        if let component, let first = component.first {
            return first
        }
        return .empty
    }

    public static func buildEither(first component: [ViewNode]) -> ViewNode {
        component.first ?? .empty
    }

    public static func buildEither(second component: [ViewNode]) -> ViewNode {
        component.first ?? .empty
    }

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
