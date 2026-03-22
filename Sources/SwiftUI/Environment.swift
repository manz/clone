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
nonisolated(unsafe) private var _globalEnvironment = EnvironmentValues()

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
public struct DismissAction: @unchecked Sendable {
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

    public var tabViewBottomAccessoryPlacement: TabViewBottomAccessoryPlacement {
        get { .automatic }
        set {}
    }
}

/// Placement for tab view bottom accessory.
public enum TabViewBottomAccessoryPlacement: Sendable {
    case automatic
    case inline
}

/// A mode that indicates whether a view is currently presented.
public struct PresentationMode {
    public var isPresented: Bool { true }
    public mutating func dismiss() {}
}

// MARK: - EnvironmentObject storage

/// Global store for environment objects. Views set them via `.environmentObject()`,
/// child views read them via `@EnvironmentObject`.
public final class EnvironmentObjectStore: @unchecked Sendable {
    public static let shared = EnvironmentObjectStore()
    private var objects: [ObjectIdentifier: AnyObject] = [:]

    public func set<T: AnyObject>(_ object: T) {
        objects[ObjectIdentifier(T.self)] = object
    }

    public func get<T: AnyObject>(_ type: T.Type) -> T? {
        objects[ObjectIdentifier(type)] as? T
    }
}

// MARK: - @EnvironmentObject

/// A property wrapper that reads an observable object from the environment.
@MainActor
@propertyWrapper
public struct EnvironmentObject<ObjectType: AnyObject> {
    public init() {}

    public var wrappedValue: ObjectType {
        get {
            guard let obj = EnvironmentObjectStore.shared.get(ObjectType.self) else {
                fatalError("No EnvironmentObject of type \(ObjectType.self) found. Ensure .environmentObject() is called on an ancestor view.")
            }
            return obj
        }
        set {
            EnvironmentObjectStore.shared.set(newValue)
        }
    }

    public var projectedValue: Wrapper {
        Wrapper(object: EnvironmentObjectStore.shared.get(ObjectType.self))
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
nonisolated(unsafe) private var _appStorageBacking: [String: Any] = [:]

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
/// Zero-size — uses global storage so it doesn't affect memberwise init access level.
@MainActor @preconcurrency
@propertyWrapper
public struct FocusState<Value: Hashable> {
    // Global storage keyed by object identity — prevents stored property in struct
    private static var _storage: [ObjectIdentifier: Any] { get { [:] } set {} }

    public var wrappedValue: Value {
        get { FocusState._defaultValue }
        nonmutating set { /* no-op on Clone */ }
    }

    public var projectedValue: Binding<Value> {
        Binding(
            get: { FocusState._defaultValue },
            set: { _ in }
        )
    }

    // NO init(wrappedValue:) — this is intentional.
    // Without it, Swift excludes @FocusState from memberwise init synthesis,
    // matching Apple's behavior. FocusState is always default-initialized via init().
    public init() {}

    private static var _defaultValue: Value {
        if Value.self == Bool.self { return false as! Value }
        if let nilType = Value.self as? any ExpressibleByNilLiteral.Type {
            return nilType.init(nilLiteral: ()) as! Value
        }
        fatalError("FocusState requires Bool or Optional type")
    }
}

extension FocusState where Value == Bool {
    public init() {}
}

extension FocusState where Value: ExpressibleByNilLiteral {
    public init() {}
}
