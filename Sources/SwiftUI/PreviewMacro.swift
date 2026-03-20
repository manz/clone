import Foundation

/// `#Preview` macro — discards the body at compile time. Provided by SwiftDataMacros plugin.
@freestanding(declaration)
public macro Preview(_ name: String = "Preview", body: @escaping () -> Any) = #externalMacro(module: "SwiftDataMacros", type: "PreviewMacro")

/// A type that produces view previews in Xcode.
public protocol PreviewProvider {
    associatedtype Previews: View
    static var previews: Previews { get }
}
