import Foundation

/// A control for selecting from a set of mutually exclusive values.
/// Matches Apple's SwiftUI `Picker` struct.
public struct Picker: View {
    let child: ViewNode

    public init(
        _ title: String,
        selection: Binding<String>,
        @ViewBuilder content: () -> [ViewNode]
    ) {
        self.child = .picker(selection: selection.wrappedValue, label: _resolve(Text(title)), children: content())
    }

    public var body: ViewNode {
        child
    }
}
