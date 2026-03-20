import Foundation

/// A property wrapper that creates a namespace for matched geometry effects.
@propertyWrapper
public struct Namespace: Sendable {
    /// A unique identifier within a namespace.
    public struct ID: Hashable, Sendable {
        let value: Int
        public init() { self.value = 0 }
    }

    public var wrappedValue: ID = ID()
    public init() {}
}
