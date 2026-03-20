import Foundation

/// A control that displays an editable text interface.
/// Matches Apple's SwiftUI `TextField` struct.
public struct TextField: View {
    let child: ViewNode

    /// `TextField("Placeholder", text:)` — text input box with placeholder.
    public init(_ placeholder: String, text: Binding<String>) {
        self.child = .textField(placeholder: placeholder, text: text.wrappedValue)
    }

    public var body: ViewNode {
        child
    }
}
