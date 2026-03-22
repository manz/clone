import Foundation

/// @State property wrapper with persistent storage across frame rebuilds.
/// Uses StateGraph keyed by source location for stable identity.
@MainActor @preconcurrency
@propertyWrapper
public struct State<Value> {
    private let slot: StateGraph.Slot

    public init(wrappedValue: Value, file: String = #fileID, line: Int = #line) {
        self.slot = StateGraph.shared.slot(initialValue: wrappedValue, file: file, line: line)
    }

    /// Compatibility alias used by Apple's SwiftUI.
    public init(initialValue: Value, file: String = #fileID, line: Int = #line) {
        self.slot = StateGraph.shared.slot(initialValue: initialValue, file: file, line: line)
    }

    public var wrappedValue: Value {
        get { slot.value as! Value }
        nonmutating set { slot.value = newValue }
    }

    public var projectedValue: Binding<Value> {
        Binding(
            get: { self.slot.value as! Value },
            set: { self.slot.value = $0 }
        )
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
