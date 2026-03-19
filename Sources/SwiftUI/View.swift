/// The core protocol for SwiftUI views.
public protocol View {
    associatedtype Body: View
    var body: Body { get }
}

/// ViewNode is the terminal View — its body is itself.
extension ViewNode: View {
    public typealias Body = ViewNode
    public var body: ViewNode { self }
}

/// Color as a View — renders as a filled rect.
extension Color: View {
    public typealias Body = ViewNode
    public var body: ViewNode {
        .rect(width: nil, height: nil, fill: self)
    }
}
