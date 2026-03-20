import Foundation

/// A view that shows the progress toward completion of a task.
/// Matches Apple's SwiftUI `ProgressView` struct.
public struct ProgressView<Label: View>: View {
    let label: ViewNode

    public var body: ViewNode {
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
        self.label = Text(titleKey).body
    }

    /// Creates a progress view with a progress value.
    public init(value: Double?, total: Double = 1.0) {
        self.label = .empty
    }

    /// Creates a progress view with a label and value.
    public init(_ titleKey: String, value: Double?, total: Double = 1.0) {
        self.label = Text(titleKey).body
    }
}

extension ProgressView where Label == ViewNode {
    /// Creates a progress view with a custom label.
    public init(@ViewBuilder label: () -> [ViewNode]) {
        self.label = .vstack(alignment: .leading, spacing: 0, children: label())
    }
}
