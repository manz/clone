import Foundation

@resultBuilder
public struct ViewBuilder {
    // MARK: - buildExpression: wrap each statement

    public static func buildExpression<V: View>(_ expression: V) -> V {
        expression
    }

    public static func buildExpression(_ expression: Never) -> Never {}

    // MARK: - buildBlock: compose statements

    // Empty block
    public static func buildBlock() -> EmptyView { EmptyView() }

    // Single view passthrough
    public static func buildBlock<C: View>(_ content: C) -> C { content }

    // Multiple views → TupleView
    public static func buildBlock<C0: View, C1: View>(_ c0: C0, _ c1: C1) -> TupleView<(C0, C1)> {
        TupleView((c0, c1))
    }
    public static func buildBlock<C0: View, C1: View, C2: View>(_ c0: C0, _ c1: C1, _ c2: C2) -> TupleView<(C0, C1, C2)> {
        TupleView((c0, c1, c2))
    }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> TupleView<(C0, C1, C2, C3)> {
        TupleView((c0, c1, c2, c3))
    }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4) -> TupleView<(C0, C1, C2, C3, C4)> {
        TupleView((c0, c1, c2, c3, c4))
    }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5) -> TupleView<(C0, C1, C2, C3, C4, C5)> {
        TupleView((c0, c1, c2, c3, c4, c5))
    }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6) -> TupleView<(C0, C1, C2, C3, C4, C5, C6)> {
        TupleView((c0, c1, c2, c3, c4, c5, c6))
    }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7) -> TupleView<(C0, C1, C2, C3, C4, C5, C6, C7)> {
        TupleView((c0, c1, c2, c3, c4, c5, c6, c7))
    }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View, C8: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8) -> TupleView<(C0, C1, C2, C3, C4, C5, C6, C7, C8)> {
        TupleView((c0, c1, c2, c3, c4, c5, c6, c7, c8))
    }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View, C8: View, C9: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9) -> TupleView<(C0, C1, C2, C3, C4, C5, C6, C7, C8, C9)> {
        TupleView((c0, c1, c2, c3, c4, c5, c6, c7, c8, c9))
    }

    // MARK: - buildPartialBlock (allows unlimited children)

    public static func buildPartialBlock<C: View>(first content: C) -> C { content }

    public static func buildPartialBlock<C0: View, C1: View>(accumulated: C0, next: C1) -> TupleView<(C0, C1)> {
        TupleView((accumulated, next))
    }

    public static func buildPartialBlock<T, C: View>(accumulated: TupleView<T>, next: C) -> TupleView<(TupleView<T>, C)> {
        TupleView((accumulated, next))
    }

    // Never
    public static func buildBlock(_ n: Never) -> Never {}

    // MARK: - Conditionals

    public static func buildEither<TrueContent: View, FalseContent: View>(first component: TrueContent) -> _ConditionalContent<TrueContent, FalseContent> {
        .trueContent(component)
    }

    public static func buildEither<TrueContent: View, FalseContent: View>(second component: FalseContent) -> _ConditionalContent<TrueContent, FalseContent> {
        .falseContent(component)
    }

    // if without else
    public static func buildOptional<V: View>(_ component: V?) -> V? {
        component
    }

    // for...in loops
    public static func buildArray<V: View>(_ components: [V]) -> _ForEachView<V> {
        _ForEachView(views: components)
    }

    // #if / availability
    public static func buildLimitedAvailability<V: View>(_ content: V) -> AnyView {
        AnyView(content)
    }
}

// MARK: - TupleView

/// Holds multiple views — produced by ViewBuilder when body has multiple statements.
public struct TupleView<T>: _PrimitiveView {
    nonisolated(unsafe) public let value: T
    nonisolated public init(_ value: T) { self.value = value }

    public var _nodeRepresentation: ViewNode {
        // Use Mirror to extract child views and resolve them
        var nodes: [ViewNode] = []
        Mirror(reflecting: value).children.forEach { child in
            if let view = child.value as? any View {
                nodes.append(_resolve(view))
            }
        }
        if nodes.count == 1 { return nodes[0] }
        return .vstack(alignment: .leading, spacing: 0, children: nodes)
    }
}

// MARK: - _ConditionalContent

/// Holds either of two view types — produced by if/else in ViewBuilder.
public enum _ConditionalContent<TrueContent: View, FalseContent: View>: _PrimitiveView {
    case trueContent(TrueContent)
    case falseContent(FalseContent)

    public var _nodeRepresentation: ViewNode {
        switch self {
        case .trueContent(let view): return _resolve(view)
        case .falseContent(let view): return _resolve(view)
        }
    }
}

// MARK: - Optional View conformance

extension Optional: View where Wrapped: View {
    public typealias Body = Never
    public var body: Never { fatalError() }
}
extension Optional: _PrimitiveView where Wrapped: View {
    public var _nodeRepresentation: ViewNode {
        if let self { return _resolve(self) }
        return .empty
    }
}

// MARK: - _ForEachView (for buildArray)

public struct _ForEachView<Element: View>: _PrimitiveView {
    nonisolated(unsafe) let views: [Element]
    public var _nodeRepresentation: ViewNode {
        .vstack(alignment: .leading, spacing: 0, children: views.map { _resolve($0) })
    }
}

// MARK: - Convenience initializers using ViewBuilder (internal)

@MainActor public extension ViewNode {
    static func vstack<Content: View>(
        alignment: HAlignment = .center,
        spacing: CGFloat = 8,
        @ViewBuilder content: () -> Content
    ) -> ViewNode {
        .vstack(alignment: alignment, spacing: spacing, children: _flattenToNodes(content()))
    }

    static func hstack<Content: View>(
        alignment: VAlignment = .center,
        spacing: CGFloat = 8,
        @ViewBuilder content: () -> Content
    ) -> ViewNode {
        .hstack(alignment: alignment, spacing: spacing, children: _flattenToNodes(content()))
    }

    static func zstack<Content: View>(@ViewBuilder content: () -> Content) -> ViewNode {
        .zstack(children: _flattenToNodes(content()))
    }
}

// MARK: - Flatten any View tree to [ViewNode]

/// Flattens a View (possibly TupleView, ForEach, etc.) into a flat array of ViewNodes.
func _flattenToNodes<V: View>(_ view: V) -> [ViewNode] {
    if let tuple = view as? any _TupleViewProtocol {
        return tuple._flatNodes
    }
    if let forEach = view as? any _ForEachProtocol {
        return forEach._flatNodes
    }
    if let nodes = view as? [ViewNode] {
        return nodes
    }
    return [_resolve(view)]
}

/// Protocol to extract children from TupleView without knowing T.
protocol _TupleViewProtocol {
    var _flatNodes: [ViewNode] { get }
}

extension TupleView: @preconcurrency _TupleViewProtocol {
    var _flatNodes: [ViewNode] {
        var nodes: [ViewNode] = []
        Mirror(reflecting: value).children.forEach { child in
            if let view = child.value as? any View {
                nodes.append(contentsOf: _flattenToNodes(view))
            }
        }
        return nodes
    }
}

/// Protocol to extract children from _ForEachView.
protocol _ForEachProtocol {
    var _flatNodes: [ViewNode] { get }
}

extension _ForEachView: @preconcurrency _ForEachProtocol {
    var _flatNodes: [ViewNode] {
        views.map { _resolve($0) }
    }
}
