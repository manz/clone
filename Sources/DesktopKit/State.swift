import Foundation

/// Minimal @State property wrapper with dirty tracking.
/// In a full implementation this would trigger re-renders through the reconciler.
@propertyWrapper
public final class State<Value> {
    private var _value: Value
    private(set) public var isDirty: Bool = false

    public init(wrappedValue: Value) {
        self._value = wrappedValue
    }

    public var wrappedValue: Value {
        get { _value }
        set {
            _value = newValue
            isDirty = true
        }
    }

    public var projectedValue: Binding<Value> {
        Binding(
            get: { self._value },
            set: { self.wrappedValue = $0 }
        )
    }

    public func clearDirty() {
        isDirty = false
    }
}

/// Two-way binding to a value.
public struct Binding<Value> {
    private let getter: () -> Value
    private let setter: (Value) -> Void

    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.getter = get
        self.setter = set
    }

    public var wrappedValue: Value {
        get { getter() }
        nonmutating set { setter(newValue) }
    }
}
