import Foundation

/// A control that displays an editable text interface.
/// Matches Apple's SwiftUI `TextField` struct.
public struct TextField: View {
    let child: ViewNode

    /// `TextField("Placeholder", text:)` — text input box with placeholder.
    public init(_ placeholder: String, text: Binding<String>) {
        self.child = .textField(placeholder: placeholder, text: text.wrappedValue)
    }

    /// `TextField("Placeholder", text:, onEditingChanged:)` — with editing callback.
    public init(_ placeholder: String, text: Binding<String>, onEditingChanged: @escaping (Bool) -> Void) {
        self.child = .textField(placeholder: placeholder, text: text.wrappedValue)
    }

    /// `TextField("Placeholder", text:, onCommit:)` — with commit callback.
    public init(_ placeholder: String, text: Binding<String>, onCommit: @escaping () -> Void) {
        self.child = .textField(placeholder: placeholder, text: text.wrappedValue)
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
        self.child = .textField(placeholder: placeholder, text: text.wrappedValue)
    }

    /// `TextField("Label", text:, axis:)` — with expansion axis.
    public init(_ placeholder: String, text: Binding<String>, axis: Axis) {
        self.child = .textField(placeholder: placeholder, text: text.wrappedValue)
    }

    public var body: ViewNode {
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
