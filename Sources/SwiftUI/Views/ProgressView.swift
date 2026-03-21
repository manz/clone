import Foundation

/// A view that shows the progress toward completion of a task.
/// Matches Apple's SwiftUI `ProgressView` struct.
public struct ProgressView<Label: View>: _PrimitiveView {
    let label: ViewNode

    public var _nodeRepresentation: ViewNode {
        // Render as a horizontal bar with a label
        .hstack(alignment: .center, spacing: 8, children: [
            // Simple progress bar placeholder
            .roundedRect(width: 100, height: 4, radius: 2, fill: .accentColor),
            label,
        ])
    }
}

extension ProgressView where Label == Text {
    /// Creates an indeterminate progress view.
    public init() {
        self.label = .empty
    }

    /// Creates a progress view with a text label.
    public init(_ titleKey: String) {
        self.label = _resolve(Text(titleKey))
    }

    /// Creates a progress view with a progress value.
    public init(value: Double?, total: Double = 1.0) {
        self.label = .empty
    }

    /// Creates a progress view with a label and value.
    public init(_ titleKey: String, value: Double?, total: Double = 1.0) {
        self.label = _resolve(Text(titleKey))
    }
}

extension ProgressView where Label == ViewNode {
    /// Creates a progress view with a custom label.
    public init(@ViewBuilder label: () -> [ViewNode]) {
        self.label = .vstack(alignment: .leading, spacing: 0, children: label())
    }

    /// Creates a progress view with value and label/currentValueLabel closures.
    public init<CurrentValueLabel: View>(value: Double?, total: Double = 1.0, @ViewBuilder label: () -> [ViewNode], @ViewBuilder currentValueLabel: () -> CurrentValueLabel) {
        let labelNodes = label()
        self.label = labelNodes.count == 1 ? labelNodes[0] : .vstack(alignment: .leading, spacing: 0, children: labelNodes)
    }

    /// Creates a progress view with value and label closure.
    public init(value: Double?, total: Double = 1.0, @ViewBuilder label: () -> [ViewNode]) {
        let labelNodes = label()
        self.label = labelNodes.count == 1 ? labelNodes[0] : .vstack(alignment: .leading, spacing: 0, children: labelNodes)
    }
}
