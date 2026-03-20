import Foundation

/// A standard label for user interface items, consisting of an icon and a title.
/// Matches Apple's SwiftUI `Label` struct.
public struct Label: View {
    let child: ViewNode

    /// `Label("Wi-Fi", systemImage: "wifi")` — icon + text. Matches Apple's SwiftUI.
    public init(_ title: String, systemImage: String) {
        self.child = .hstack(alignment: .center, spacing: 8, children: [
            .image(name: systemImage, width: 16, height: 16),
            .text(title, fontSize: 13, color: .primary),
        ])
    }

    /// `Label("Wi-Fi", systemImage: "wifi", iconColor: .blue)` — icon rounded rect + text.
    /// Since we don't have SF Symbols, `systemImage` is ignored visually but the icon color is used.
    public init(_ title: String, systemImage: String, iconColor: Color) {
        self.child = .hstack(alignment: .center, spacing: 8, children: [
            .roundedRect(width: 20, height: 20, radius: 5, fill: iconColor),
            .text(title, fontSize: 13, color: .primary),
        ])
    }

    public var body: ViewNode {
        child
    }
}
