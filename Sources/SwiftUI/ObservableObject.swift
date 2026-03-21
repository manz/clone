// Re-export Combine's ObservableObject, Published, ObservableObjectPublisher.
@_exported import Combine

// StateObject and ObservedObject are SwiftUI property wrappers (not in Combine).
// We provide them here for Clone. On real macOS SwiftUI, Apple provides them.

/// A property wrapper that instantiates and owns an observable object.
@MainActor @preconcurrency
@propertyWrapper
public struct StateObject<ObjectType: ObservableObject> {
    public var wrappedValue: ObjectType

    public init(wrappedValue: ObjectType) {
        self.wrappedValue = wrappedValue
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
