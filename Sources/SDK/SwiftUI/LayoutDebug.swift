import Foundation

/// App-side layout debugging. When enabled, CommandFlattener emits
/// thin red outlines around every LayoutNode frame and a highlight
/// around every `.onTap` frame — the Clone equivalent of Xcode's
/// "Debug View Hierarchy" but drawn inline in the app's own surface.
///
/// Toggle via env var at launch: `CLONE_DEBUG_OUTLINES=1` or `=taps`.
public final class LayoutDebug: @unchecked Sendable {
    public enum Mode {
        /// No outlines.
        case off
        /// 1px red outline on every laid-out frame.
        case all
        /// 2px green outline on `.onTap` frames only.
        case taps
    }

    public static let shared = LayoutDebug()

    public var mode: Mode

    private init() {
        let raw = ProcessInfo.processInfo.environment["CLONE_DEBUG_OUTLINES"]?.lowercased()
        switch raw {
        case "1", "true", "all": self.mode = .all
        case "taps": self.mode = .taps
        default: self.mode = .off
        }
    }
}
