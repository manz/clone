import Foundation

/// A control that toggles between on and off states.
/// Matches Apple's SwiftUI `Toggle` struct.
public struct Toggle: _PrimitiveView {
    let child: ViewNode

    /// `Toggle(isOn:) { label }` — renders interactive toggle.
    public init(isOn: Binding<Bool>, @ViewBuilder label: () -> some View) {
        let labelContent = _flattenToNodes(label())
        let labelNode = labelContent.count == 1 ? labelContent[0] : ViewNode.hstack(alignment: .center, spacing: 4, children: labelContent)
        let toggleNode = ViewNode.toggle(isOn: isOn.wrappedValue, label: labelNode)
        let tapId = TapRegistry.shared.register {
            isOn.wrappedValue.toggle()
        }
        self.child = .onTap(id: tapId, child: toggleNode)
    }

    /// `Toggle("Label", isOn:)` — convenience.
    public init(_ title: String, isOn: Binding<Bool>) {
        let toggleNode = ViewNode.toggle(isOn: isOn.wrappedValue, label: _resolve(Text(title)))
        let tapId = TapRegistry.shared.register {
            isOn.wrappedValue.toggle()
        }
        self.child = .onTap(id: tapId, child: toggleNode)
    }

    public var _nodeRepresentation: ViewNode {
        child
    }
}
