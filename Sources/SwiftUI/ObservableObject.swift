import Foundation

/// A type of object with a publisher that emits before the object has changed.
/// In clone's frame-loop architecture, re-renders happen every frame, so this
/// protocol exists for API compatibility rather than triggering updates.
public protocol ObservableObject: AnyObject {
    associatedtype ObjectWillChangePublisher = ObservableObjectPublisher
    var objectWillChange: ObjectWillChangePublisher { get }
}

/// A publisher that publishes changes from observable objects.
/// Stub implementation — the frame loop handles re-rendering.
public final class ObservableObjectPublisher: Sendable {
    public init() {}
    public func send() {}
}

/// Default implementation so conformers don't need to provide one.
extension ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    public var objectWillChange: ObservableObjectPublisher {
        ObservableObjectPublisher()
    }
}

/// A property wrapper that publishes value changes.
/// In clone, the frame loop rebuilds every frame, so this is API-compatible only.
@propertyWrapper
public final class Published<Value> {
    public var wrappedValue: Value {
        didSet {
            publisher.send()
        }
    }

    private let publisher = ObservableObjectPublisher()

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public var projectedValue: Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { self.wrappedValue = $0 }
        )
    }
}

/// A property wrapper that subscribes to an observable object.
/// API-compatible stub — the frame loop handles re-rendering.
@propertyWrapper
public final class ObservedObject<ObjectType: ObservableObject> {
    public var wrappedValue: ObjectType

    public init(wrappedValue: ObjectType) {
        self.wrappedValue = wrappedValue
    }

    public var projectedValue: Wrapper {
        Wrapper(object: wrappedValue)
    }

    public struct Wrapper {
        let object: ObjectType
    }
}

/// A property wrapper that instantiates and owns an observable object.
/// API-compatible stub — the frame loop handles re-rendering.
@propertyWrapper
public final class StateObject<ObjectType: ObservableObject> {
    public var wrappedValue: ObjectType

    public init(wrappedValue: ObjectType) {
        self.wrappedValue = wrappedValue
    }

    public var projectedValue: ObservedObject<ObjectType>.Wrapper {
        ObservedObject.Wrapper(object: wrappedValue)
    }
}
