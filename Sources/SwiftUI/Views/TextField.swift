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

    public var body: ViewNode {
        child
    }
}
