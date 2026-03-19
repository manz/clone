/// A component that produces a ViewNode tree.
public protocol Component {
    func body() -> ViewNode
}
