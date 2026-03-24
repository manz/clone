/// A scene that presents a group of identically structured windows.
public struct WindowGroup<Content: View>: Scene {
    public typealias Body = _NeverScene
    public var body: _NeverScene { fatalError("WindowGroup is a primitive scene") }

    public let title: String
    public let content: () -> Content

    public init(_ title: String = "", @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
}
