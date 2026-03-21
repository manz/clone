import Foundation

/// A control for selecting from a set of mutually exclusive values.
/// Matches Apple's SwiftUI `Picker` struct.
public struct Picker<SelectionValue: Hashable>: _PrimitiveView {
    let child: ViewNode

    public init(
        _ title: String,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> some View
    ) {
        self.child = .picker(selection: "\(selection.wrappedValue)", label: _resolve(Text(title)), children: _flattenToNodes(content()))
    }

    public var _nodeRepresentation: ViewNode {
        child
    }
}
