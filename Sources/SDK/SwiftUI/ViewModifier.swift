import Foundation

/// A modifier that you apply to a view or another view modifier,
/// producing a different version of the original value.
@preconcurrency @MainActor
public protocol ViewModifier {
    associatedtype Body: View
    typealias Content = _ViewModifierContent
    @ViewBuilder func body(content: Content) -> Body
}

/// A view wrapper used as the `Content` type in `ViewModifier.body(content:)`.
/// User code calls modifiers on this type (e.g. `.frame()`, `.padding()`).
public struct _ViewModifierContent: _PrimitiveView {
    let node: ViewNode
    public var _nodeRepresentation: ViewNode { node }
}

extension View {
    public func modifier<T: ViewModifier>(_ modifier: T) -> ViewNode {
        _resolve(modifier.body(content: _ViewModifierContent(node: _resolve(self))))
    }
}
