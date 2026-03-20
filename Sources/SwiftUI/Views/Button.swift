import Foundation

/// A control that initiates an action.
/// Matches Apple's SwiftUI `Button` struct.
public struct Button: View {
    let child: ViewNode

    /// `Button("Tap") { action }` — label string variant.
    public init(_ label: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        let color: Color = role == .destructive ? .red : .blue
        self.child = Text(label)
            .foregroundColor(color)
            .onTapGesture(action)
    }

    /// `Button(action: { }) { label }` — custom label variant.
    public init(role: ButtonRole? = nil, action: @escaping () -> Void, @ViewBuilder label: () -> [ViewNode]) {
        let content = label()
        let labelNode = content.count == 1 ? content[0] : ViewNode.hstack(alignment: .center, spacing: 4, children: content)
        self.child = labelNode.onTapGesture(action)
    }

    public var body: ViewNode {
        child
    }
}
