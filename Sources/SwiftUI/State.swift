import Foundation

/// Minimal @State property wrapper with dirty tracking.
/// In a full implementation this would trigger re-renders through the reconciler.
@MainActor @preconcurrency
@propertyWrapper
public struct State<Value> {
    private final class Storage {
        var value: Value
        var isDirty: Bool = false
        init(_ value: Value) { self.value = value }
    }
    private let storage: Storage

    public init(wrappedValue: Value) {
        self.storage = Storage(wrappedValue)
    }

    /// Compatibility alias used by Apple's SwiftUI.
    public init(initialValue: Value) {
        self.storage = Storage(initialValue)
    }

    public var wrappedValue: Value {
        get { storage.value }
        nonmutating set {
            storage.value = newValue
            storage.isDirty = true
        }
    }

    public var projectedValue: Binding<Value> {
        Binding(
            get: { self.storage.value },
            set: { self.wrappedValue = $0 }
        )
    }

    public var isDirty: Bool { storage.isDirty }

    public func clearDirty() {
        storage.isDirty = false
    }
}

/// Two-way binding to a value.
@dynamicMemberLookup
@propertyWrapper
public struct Binding<Value> {
    private let getter: () -> Value
    private let setter: (Value) -> Void

    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.getter = get
        self.setter = set
    }

    public init(projectedValue: Binding<Value>) {
        self.getter = projectedValue.getter
        self.setter = projectedValue.setter
    }

    public var wrappedValue: Value {
        get { getter() }
        nonmutating set { setter(newValue) }
    }

    public var projectedValue: Binding<Value> { self }

    /// Creates a binding with an immutable value.
    public static func constant(_ value: Value) -> Binding<Value> {
        Binding(get: { value }, set: { _ in })
    }

    /// Dynamic member lookup — `$binding.member` produces `Binding<Member>`.
    public subscript<Subject>(dynamicMember keyPath: WritableKeyPath<Value, Subject>) -> Binding<Subject> {
        Binding<Subject>(
            get: { self.wrappedValue[keyPath: keyPath] },
            set: { self.wrappedValue[keyPath: keyPath] = $0 }
        )
    }
}

extension Binding where Value: ExpressibleByNilLiteral {
    /// Creates a nil binding.
    public init() {
        self.init(get: { nil }, set: { _ in })
    }
}
