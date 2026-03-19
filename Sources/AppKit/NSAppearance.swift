/// The visual appearance of the app (light or dark).
public enum NSAppearanceStyle: Sendable {
    case aqua
    case darkAqua
}

/// Manages the current system appearance. Shared across AppKit and SwiftUI.
public final class NSAppearance: @unchecked Sendable {
    public static let shared = NSAppearance()

    public var style: NSAppearanceStyle = .aqua

    public var isDark: Bool { style == .darkAqua }

    private init() {}
}
