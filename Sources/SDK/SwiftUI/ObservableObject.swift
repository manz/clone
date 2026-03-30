// Clone's ObservableObject, @Published, and related types.
// On macOS, re-export Combine (Foundation auto-imports it).
// On Linux, provide our own minimal implementation.

#if canImport(Combine)
@_exported import Combine

#else
import Foundation

// MARK: - Publisher / AnyCancellable (minimal stubs)

/// Minimal Publisher protocol — just enough for onReceive() signatures.
public protocol Publisher {
    associatedtype Output
}

/// A type-erased cancellable that executes a closure on deinit/cancel.
public final class AnyCancellable: Hashable {
    private var cancelBlock: (() -> Void)?

    public init(_ cancel: @escaping () -> Void = {}) {
        self.cancelBlock = cancel
    }

    public func cancel() {
        cancelBlock?()
        cancelBlock = nil
    }

    deinit { cancel() }

    public func store(in set: inout Set<AnyCancellable>) { set.insert(self) }
    public static func == (lhs: AnyCancellable, rhs: AnyCancellable) -> Bool { lhs === rhs }
    public func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}

// MARK: - ObservableObjectPublisher

/// A publisher that emits before the object changes.
/// Subscribers (StateObject) call sink() to get notified.
public final class ObservableObjectPublisher: @unchecked Sendable {
    private var handlers: [() -> Void] = []

    public init() {}

    /// Notify all subscribers that the object is about to change.
    public func send() {
        for handler in handlers {
            handler()
        }
    }

    /// Subscribe to change notifications.
    public func sink(receiveValue: @escaping () -> Void) -> AnyCancellable {
        handlers.append(receiveValue)
        let index = handlers.count - 1
        return AnyCancellable { [weak self] in
            // Replace with no-op to avoid index shifting
            if let self, index < self.handlers.count {
                self.handlers[index] = {}
            }
        }
    }

    // Overload that matches Combine's sink(receiveValue:) where Output is Void
    public func sink(_ block: @escaping (Void) -> Void) -> AnyCancellable {
        sink(receiveValue: { block(()) })
    }

    public func assign<Root>(to keyPath: ReferenceWritableKeyPath<Root, Void>, on object: Root) -> AnyCancellable {
        sink(receiveValue: {})
    }
}

// MARK: - ObservableObject protocol

/// A type that publishes changes before its properties change.
/// Clone's replacement for Combine.ObservableObject.
public protocol ObservableObject: AnyObject {
    associatedtype ObjectWillChangePublisher = ObservableObjectPublisher
    var objectWillChange: ObservableObjectPublisher { get }
}

extension ObservableObject {
    public var objectWillChange: ObservableObjectPublisher { ObservableObjectPublisher() }
}

// MARK: - @Published

/// Property wrapper that calls objectWillChange.send() on the enclosing ObservableObject.
/// Uses _enclosingInstance subscript to access the owning object.
@propertyWrapper
public struct Published<Value> {
    private var storage: Value

    public init(wrappedValue: Value) {
        self.storage = wrappedValue
    }

    // Direct access (when no enclosing instance is available)
    public var wrappedValue: Value {
        get { storage }
        set { storage = newValue }
    }

    // Subscript-based access — called when the property wrapper is on a class.
    // Swift calls this instead of wrappedValue get/set when the enclosing instance
    // conforms to ObservableObject.
    public static subscript<EnclosingSelf: ObservableObject>(
        _enclosingInstance observed: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Published<Value>>
    ) -> Value {
        get {
            observed[keyPath: storageKeyPath].storage
        }
        set {
            observed.objectWillChange.send()
            observed[keyPath: storageKeyPath].storage = newValue
        }
    }
}

#endif // !canImport(Combine)

// MARK: - StateObject / ObservedObject

/// A property wrapper that instantiates and owns an observable object.
/// Uses StateGraph for persistence — the object is created once and reused across frames.
/// Subscribes to objectWillChange so @Published mutations trigger re-renders.
@MainActor @preconcurrency
@propertyWrapper
public struct StateObject<ObjectType: ObservableObject> {
    private let slot: StateGraph.Slot

    public init(wrappedValue: ObjectType, file: String = #fileID, line: Int = #line) {
        self.slot = StateGraph.shared.slot(initialValue: wrappedValue, file: file, line: line)
        let obj = slot.value as! ObjectType
        if slot.subscription == nil {
            slot.subscription = obj.objectWillChange.sink { _ in
                StateGraph.shared.invalidate()
            }
        }
    }

    public var wrappedValue: ObjectType {
        get { slot.value as! ObjectType }
    }

    public var projectedValue: ObservedObject<ObjectType>.Wrapper {
        ObservedObject<ObjectType>.Wrapper(object: wrappedValue)
    }
}

/// A property wrapper that subscribes to an observable object.
@MainActor @preconcurrency
@propertyWrapper
public struct ObservedObject<ObjectType: ObservableObject> {
    public var wrappedValue: ObjectType

    public init(wrappedValue: ObjectType) {
        self.wrappedValue = wrappedValue
    }

    public var projectedValue: Wrapper {
        Wrapper(object: wrappedValue)
    }

    @dynamicMemberLookup
    public struct Wrapper {
        public let object: ObjectType

        public subscript<Value>(dynamicMember keyPath: ReferenceWritableKeyPath<ObjectType, Value>) -> Binding<Value> {
            Binding(
                get: { object[keyPath: keyPath] },
                set: { object[keyPath: keyPath] = $0 }
            )
        }
    }
}
