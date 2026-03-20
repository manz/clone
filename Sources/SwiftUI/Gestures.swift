import Foundation

/// A gesture that recognizes a drag motion.
public struct DragGesture {
    /// The attributes of a drag gesture.
    public struct Value {
        public let translation: CGSize
        public let location: CGPoint
        public let startLocation: CGPoint
        public let predictedEndTranslation: CGSize
        public let predictedEndLocation: CGPoint
    }

    public init(minimumDistance: CGFloat = 10, coordinateSpace: CoordinateSpace = .local) {}

    public func onChanged(_ action: @escaping (Value) -> Void) -> DragGesture { self }
    public func onEnded(_ action: @escaping (Value) -> Void) -> DragGesture { self }
}

/// A gesture that recognizes one or more taps.
public struct TapGesture {
    public init(count: Int = 1) {}
    public func onEnded(_ action: @escaping () -> Void) -> TapGesture { self }
    public func modifiers(_ modifiers: EventModifiers) -> TapGesture { self }
}

/// A gesture that recognizes a long press.
public struct LongPressGesture {
    public init(minimumDuration: Double = 0.5) {}
    public func onEnded(_ action: @escaping (Bool) -> Void) -> LongPressGesture { self }
}

/// A gesture that recognizes a magnification motion.
public struct MagnificationGesture {
    public init(minimumScaleDelta: CGFloat = 0.01) {}
}

/// The coordinate space for gesture values.
public enum CoordinateSpace {
    case local
    case global
    case named(AnyHashable)
}
