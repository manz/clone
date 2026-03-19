import Foundation

/// A key for accessing values in the environment.
public protocol EnvironmentKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

/// A collection of environment values propagated through a view hierarchy.
public struct EnvironmentValues {
    private var storage: [ObjectIdentifier: Any] = [:]

    public init() {}

    public subscript<K: EnvironmentKey>(key: K.Type) -> K.Value {
        get { storage[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue }
        set { storage[ObjectIdentifier(key)] = newValue }
    }
}

/// Shared global environment — in a full implementation, this would be per-view-tree.
private var _globalEnvironment = EnvironmentValues()

/// A property wrapper that reads a value from the environment.
@propertyWrapper
public struct Environment<Value> {
    private let keyPath: KeyPath<EnvironmentValues, Value>

    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        self.keyPath = keyPath
    }

    public var wrappedValue: Value {
        _globalEnvironment[keyPath: keyPath]
    }
}

// MARK: - Common environment keys

private struct DismissActionKey: EnvironmentKey {
    static let defaultValue: DismissAction = DismissAction {}
}

/// A dismiss action that can be called from the environment.
public struct DismissAction {
    private let action: () -> Void
    public init(_ action: @escaping () -> Void) { self.action = action }
    public func callAsFunction() { action() }
}

extension EnvironmentValues {
    public var dismiss: DismissAction {
        get { self[DismissActionKey.self] }
        set { self[DismissActionKey.self] = newValue }
    }
}
