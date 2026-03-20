import Foundation

/// A modifier that you apply to a view or another view modifier,
/// producing a different version of the original value.
public protocol ViewModifier {
    associatedtype Body: View
    typealias Content = ViewNode
    func body(content: Content) -> Body
}

extension View {
    public func modifier<T: ViewModifier>(_ modifier: T) -> ViewNode {
        _resolve(modifier.body(content: _resolve(self)))
    }
}
