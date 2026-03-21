import Foundation

/// A control that toggles between on and off states.
/// Matches Apple's SwiftUI `Toggle` struct.
public struct Toggle: _PrimitiveView {
    let child: ViewNode

    /// `Toggle(isOn:) { label }` — renders static representation.
    public init(isOn: Binding<Bool>, @ViewBuilder label: () -> some View) {
        let labelContent = _flattenToNodes(label())
        let labelNode = labelContent.count == 1 ? labelContent[0] : ViewNode.hstack(alignment: .center, spacing: 4, children: labelContent)
        self.child = .toggle(isOn: isOn.wrappedValue, label: labelNode)
    }

    /// `Toggle("Label", isOn:)` — convenience.
    public init(_ title: String, isOn: Binding<Bool>) {
        self.child = .toggle(isOn: isOn.wrappedValue, label: _resolve(Text(title)))
    }

    public var _nodeRepresentation: ViewNode {
        child
    }
}
