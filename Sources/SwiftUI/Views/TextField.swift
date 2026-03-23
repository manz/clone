import Foundation

/// A control that displays an editable text interface.
/// Matches Apple's SwiftUI `TextField` struct.
public struct TextField: _PrimitiveView {
    let child: ViewNode

    /// `TextField("Placeholder", text:)` — text input box with placeholder.
    public init(_ placeholder: String, text: Binding<String>) {
        let id = TextFieldRegistry.shared.register(binding: text, placeholder: placeholder)
        self.child = .textField(placeholder: placeholder, text: text.wrappedValue, registryId: id)
    }

    /// `TextField("Placeholder", text:, onEditingChanged:)` — with editing callback.
    public init(_ placeholder: String, text: Binding<String>, onEditingChanged: @escaping (Bool) -> Void) {
        let id = TextFieldRegistry.shared.register(binding: text, placeholder: placeholder)
        self.child = .textField(placeholder: placeholder, text: text.wrappedValue, registryId: id)
    }

    /// `TextField("Placeholder", text:, onCommit:)` — with commit callback.
    public init(_ placeholder: String, text: Binding<String>, onCommit: @escaping () -> Void) {
        let id = TextFieldRegistry.shared.register(binding: text, placeholder: placeholder)
        self.child = .textField(placeholder: placeholder, text: text.wrappedValue, registryId: id)
    }

    /// `TextField("Label", value:, format:)` — value binding with format style (Foundation.FormatStyle).
    public init<F: Foundation.FormatStyle>(_ placeholder: String, value: Binding<F.FormatInput>, format: F) {
        self.child = .textField(placeholder: placeholder, text: "\(value.wrappedValue)")
    }

    /// `TextField("Label", value:, format:, prompt:)` — with prompt.
    public init<F: Foundation.FormatStyle>(_ placeholder: String, value: Binding<F.FormatInput>, format: F, prompt: Text? = nil) {
        self.child = .textField(placeholder: placeholder, text: "\(value.wrappedValue)")
    }

    /// `TextField("Label", value: optionalBinding, format:)` — optional value.
    public init<V, F: Foundation.FormatStyle>(_ placeholder: String, value: Binding<V?>, format: F) where F.FormatInput == V {
        self.child = .textField(placeholder: placeholder, text: value.wrappedValue.map { "\($0)" } ?? "")
    }

    /// `TextField("Label", text:, prompt:)` — with prompt.
    public init(_ placeholder: String, text: Binding<String>, prompt: Text?) {
        let id = TextFieldRegistry.shared.register(binding: text, placeholder: placeholder)
        self.child = .textField(placeholder: placeholder, text: text.wrappedValue, registryId: id)
    }

    /// `TextField("Label", text:, axis:)` — with expansion axis.
    public init(_ placeholder: String, text: Binding<String>, axis: Axis) {
        let id = TextFieldRegistry.shared.register(binding: text, placeholder: placeholder)
        self.child = .textField(placeholder: placeholder, text: text.wrappedValue, registryId: id)
    }

    public var _nodeRepresentation: ViewNode {
        child
    }
}

// MARK: - FormatStyle

// On macOS/Darwin, Foundation provides FormatStyle, IntegerFormatStyle, etc.
// On Linux, swift-corelibs-foundation may lack them — provide stubs.
#if !canImport(Darwin)
public protocol FormatStyle {
    associatedtype FormatInput
    associatedtype FormatOutput
}

public struct IntegerFormatStyle<Value: BinaryInteger>: FormatStyle {
    public typealias FormatInput = Value
    public typealias FormatOutput = String
    public init() {}
    public func precision(_ p: NumberFormatStyleConfiguration.Precision) -> IntegerFormatStyle { self }
}

public struct FloatingPointFormatStyle<Value: BinaryFloatingPoint>: FormatStyle {
    public typealias FormatInput = Value
    public typealias FormatOutput = String
    public init() {}
    public func precision(_ p: NumberFormatStyleConfiguration.Precision) -> FloatingPointFormatStyle { self }
}

public enum NumberFormatStyleConfiguration {
    public struct Precision {
        public static func significantDigits(_ range: ClosedRange<Int>) -> Precision { Precision() }
        public static func significantDigits(_ count: Int) -> Precision { Precision() }
        public static func fractionLength(_ range: ClosedRange<Int>) -> Precision { Precision() }
        public static func fractionLength(_ count: Int) -> Precision { Precision() }
        public static func integerLength(_ range: ClosedRange<Int>) -> Precision { Precision() }
    }
}

extension FormatStyle where Self == IntegerFormatStyle<Int> {
    public static var number: IntegerFormatStyle<Int> { IntegerFormatStyle() }
}

extension FormatStyle where Self == FloatingPointFormatStyle<Double> {
    public static var number: FloatingPointFormatStyle<Double> { FloatingPointFormatStyle() }
}
#endif
