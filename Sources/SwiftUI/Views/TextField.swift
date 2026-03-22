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

    /// `TextField("Label", value:, format:)` — value binding with format style.
    public init<V>(_ placeholder: String, value: Binding<V>, format: some FormatStyle) {
        self.child = .textField(placeholder: placeholder, text: "\(value.wrappedValue)")
    }

    /// `TextField("Label", value:, format:, prompt:)` — value binding with format and prompt.
    public init<V>(_ placeholder: String, value: Binding<V>, format: some FormatStyle, prompt: Text? = nil) {
        self.child = .textField(placeholder: placeholder, text: "\(value.wrappedValue)")
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

// MARK: - FormatStyle stub

/// Minimal FormatStyle protocol for TextField value formatting.
public protocol FormatStyle {
    associatedtype FormatInput
    associatedtype FormatOutput
}

/// Integer format style — `.number` shorthand.
public struct IntegerFormatStyle<Value: BinaryInteger>: FormatStyle {
    public typealias FormatInput = Value
    public typealias FormatOutput = String
    public init() {}
}

/// Floating point format style.
public struct FloatingPointFormatStyle<Value: BinaryFloatingPoint>: FormatStyle {
    public typealias FormatInput = Value
    public typealias FormatOutput = String
    public init() {}
}

extension FormatStyle where Self == IntegerFormatStyle<Int> {
    public static var number: IntegerFormatStyle<Int> { IntegerFormatStyle() }
}

extension Int {
    public struct FormatStyle: SwiftUI.FormatStyle {
        public typealias FormatInput = Int
        public typealias FormatOutput = String
        public init() {}
    }
}

extension Optional where Wrapped == Int {
    public struct FormatStyle: SwiftUI.FormatStyle {
        public typealias FormatInput = Int?
        public typealias FormatOutput = String
        public init() {}
    }
}
