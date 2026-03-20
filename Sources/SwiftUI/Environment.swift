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

    public var presentationMode: Binding<PresentationMode> {
        .constant(PresentationMode())
    }
}

/// A mode that indicates whether a view is currently presented.
public struct PresentationMode {
    public var isPresented: Bool { true }
    public mutating func dismiss() {}
}

// MARK: - @EnvironmentObject

/// A property wrapper that reads an observable object from the environment.
@propertyWrapper
public struct EnvironmentObject<ObjectType: AnyObject> {
    private var object: ObjectType?

    public init() { self.object = nil }

    public var wrappedValue: ObjectType {
        get { object! }
        set { object = newValue }
    }

    public var projectedValue: Wrapper {
        Wrapper(object: object)
    }

    public struct Wrapper {
        let object: ObjectType?
    }
}

// MARK: - @AppStorage

/// A property wrapper that reads and writes to UserDefaults.
/// On Clone, backed by an in-memory dictionary (no UserDefaults on Linux).
@propertyWrapper
public struct AppStorage<Value> {
    private static var _storage: [String: Any] {
        get { _appStorageBacking }
        set { _appStorageBacking = newValue }
    }

    private let key: String
    private let defaultValue: Value

    public init(wrappedValue: Value, _ key: String) {
        self.key = key
        self.defaultValue = wrappedValue
    }

    public var wrappedValue: Value {
        get { AppStorage._storage[key] as? Value ?? defaultValue }
        nonmutating set { _appStorageBacking[key] = newValue }
    }

    public var projectedValue: Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { self.wrappedValue = $0 }
        )
    }
}

/// String-defaulted convenience
extension AppStorage where Value == String {
    public init(_ key: String) {
        self.key = key
        self.defaultValue = ""
    }
}

/// Bool-defaulted convenience
extension AppStorage where Value == Bool {
    public init(_ key: String) {
        self.key = key
        self.defaultValue = false
    }
}

/// Int-defaulted convenience
extension AppStorage where Value == Int {
    public init(_ key: String) {
        self.key = key
        self.defaultValue = 0
    }
}

/// Double-defaulted convenience
extension AppStorage where Value == Double {
    public init(_ key: String) {
        self.key = key
        self.defaultValue = 0.0
    }
}

/// Backing store for @AppStorage
private var _appStorageBacking: [String: Any] = [:]

// MARK: - @SceneStorage

/// A property wrapper for per-scene state. On Clone, uses the same in-memory backing as AppStorage.
@propertyWrapper
public struct SceneStorage<Value> {
    private let key: String
    private let defaultValue: Value

    public init(wrappedValue: Value, _ key: String) {
        self.key = key
        self.defaultValue = wrappedValue
    }

    public var wrappedValue: Value {
        get { _appStorageBacking[key] as? Value ?? defaultValue }
        nonmutating set { _appStorageBacking[key] = newValue }
    }

    public var projectedValue: Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { self.wrappedValue = $0 }
        )
    }
}

// MARK: - @FocusState

/// A property wrapper for focus tracking. No-op on Clone.
@propertyWrapper
public final class FocusState<Value: Hashable> {
    public var wrappedValue: Value

    public var projectedValue: Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { self.wrappedValue = $0 }
        )
    }

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
}

extension FocusState where Value == Bool {
    public convenience init() {
        self.init(wrappedValue: false)
    }
}

extension FocusState where Value: ExpressibleByNilLiteral {
    public convenience init() {
        self.init(wrappedValue: nil)
    }
}
