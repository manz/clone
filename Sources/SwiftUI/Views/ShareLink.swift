import Foundation

/// A view that controls a sharing presentation.
/// No-op on Clone — renders the label only.
public struct ShareLink<Data, PreviewImage, PreviewIcon, Label: View>: View {
    let label: ViewNode

    public var body: ViewNode {
        label
    }
}

extension ShareLink where PreviewImage == Never, PreviewIcon == Never, Label == ViewNode, Data == String {
    /// Creates a share link with a string item and default label.
    public init(item: String) {
        self.label = Text("Share").body
    }

    /// Creates a share link with a string item and text label.
    public init(_ titleKey: String, item: String) {
        self.label = Text(titleKey).body
    }
}

extension ShareLink where PreviewImage == Never, PreviewIcon == Never, Data == URL {
    /// Creates a share link with a URL item.
    public init(item: URL, @ViewBuilder label: () -> [ViewNode]) {
        self.label = .hstack(alignment: .center, spacing: 0, children: label())
    }
}
