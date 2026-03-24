import Foundation

/// Resolved icon: the Phosphor SVG filename and style variant.
public struct ResolvedIcon {
    /// Phosphor icon name (e.g. "folder", "avocado") — matches the SVG filename.
    public let name: String
    /// Which Phosphor style variant (regular, fill, duotone, etc.)
    public let style: PhosphorIconStyle
}

/// Maps SF Symbols–style icon names to Phosphor Icons SVG names.
/// SVGs live in engine/assets/phosphor-icons/SVGs/{style}/{name}[-{style}].svg
public enum PhosphorIcons {

    /// Resolve an SF Symbols-style name to a Phosphor icon name and style.
    /// Handles ".fill" and ".duotone" suffixes.
    /// Falls back to the name itself as a Phosphor icon name if not in the mapping table.
    public static func resolve(name: String) -> ResolvedIcon {
        // Detect style suffix
        if name.hasSuffix(".fill") {
            let base = String(name.dropLast(5))
            let phosphorName = sfToPhosphor[base] ?? sfToPhosphor[name] ?? base
            return ResolvedIcon(name: phosphorName, style: .fill)
        }
        if name.hasSuffix(".duotone") {
            let base = String(name.dropLast(8))
            let phosphorName = sfToPhosphor[base] ?? sfToPhosphor[name] ?? base
            return ResolvedIcon(name: phosphorName, style: .duotone)
        }

        // Check mapping table, otherwise pass through as-is (direct Phosphor name)
        if let phosphorName = sfToPhosphor[name] {
            return ResolvedIcon(name: phosphorName, style: .regular)
        }
        return ResolvedIcon(name: name, style: .regular)
    }

    // MARK: - SF Symbols → Phosphor name mapping

    /// Maps SF Symbols names to Phosphor icon names.
    /// Names not in this table are passed through directly (they're already Phosphor names).
    static let sfToPhosphor: [String: String] = [
        // Folders
        "folder":                   "folder",
        "folder.open":              "folder-open",
        "folder.notch":             "folder",
        "folder.notch.open":        "folder-open",

        // Files
        "doc":                      "file",
        "doc.text":                 "file-text",
        "doc.richtext":             "file-text",
        "file":                     "file",
        "file.text":                "file-text",
        "file.code":                "file-code",
        "file.image":               "file-image",
        "file.audio":               "file-audio",
        "file.video":               "file-video",
        "file.zip":                 "file-zip",
        "file.pdf":                 "file-pdf",
        "file.css":                 "file-css",
        "file.html":                "file-html",
        "file.js":                  "file-js",
        "file.ts":                  "file-ts",
        "file.py":                  "file-py",
        "file.rs":                  "file-rs",
        "file.doc":                 "file-doc",

        // Navigation
        "house":                    "house",
        "house.simple":             "house-simple",
        "chevron.left":             "caret-left",
        "chevron.right":            "caret-right",
        "chevron.up":               "caret-up",
        "chevron.down":             "caret-down",
        "arrow.left":               "arrow-left",
        "arrow.right":              "arrow-right",
        "arrow.up":                 "arrow-up",
        "arrow.down":               "arrow-down",
        "arrow.clockwise":          "arrow-clockwise",
        "arrow.counterclockwise":   "arrow-counter-clockwise",
        "arrow.up.left.and.arrow.down.right": "arrows-out",
        "arrows.out":               "arrows-out",
        "arrows.in":                "arrows-in",

        // Actions
        "magnifyingglass":          "magnifying-glass",
        "plus":                     "plus",
        "minus":                    "minus",
        "xmark":                    "x",
        "xmark.circle":             "x-circle",
        "checkmark":                "check",
        "checkmark.circle":         "check-circle",
        "pencil":                   "pencil-simple",
        "pencil.simple":            "pencil-simple",
        "trash":                    "trash",
        "trash.simple":             "trash-simple",
        "copy":                     "copy",
        "clipboard":                "clipboard",
        "share":                    "share",
        "share.network":            "share-network",
        "link":                     "link",
        "pin":                      "push-pin",
        "bookmark":                 "bookmark-simple",
        "tag":                      "tag",
        "star":                     "star",
        "heart":                    "heart",

        // Info & warnings
        "info.circle":              "info",
        "questionmark.circle":      "question",
        "exclamationmark.triangle": "warning",
        "exclamationmark.circle":   "warning-circle",

        // System
        "gear":                     "gear",
        "gearshape":                "gear",
        "wrench":                   "wrench",
        "slider.horizontal.3":      "sliders-horizontal",
        "paintbrush":               "paint-brush",
        "textformat":               "text-aa",
        "terminal":                 "terminal",

        // Hardware & storage
        "desktopcomputer":          "desktop",
        "display":                  "monitor",
        "internaldrive":            "hard-drives",
        "externaldrive":            "hard-drive",
        "cpu":                      "cpu",
        "memorychip":               "cpu",
        "battery.100":              "battery-full",
        "printer":                  "printer",
        "plug":                     "plug",

        // Media
        "photo":                    "image",
        "music.note":               "music-note",
        "music.note.list":          "music-notes",
        "video":                    "video-camera",

        // Communication
        "envelope":                 "envelope",
        "bubble.left":              "chat",
        "bell":                     "bell",
        "person":                   "user",
        "person.2":                 "users",

        // Security
        "lock":                     "lock",
        "lock.open":                "lock-open",
        "key":                      "key",
        "shield":                   "shield",
        "shield.checkered":         "shield-check",

        // Network & cloud
        "globe":                    "globe",
        "network":                  "globe-simple",
        "wifi":                     "wifi-high",
        "cloud":                    "cloud",
        "icloud":                   "cloud",

        // View controls
        "eye":                      "eye",
        "eye.slash":                "eye-slash",
        "sidebar.left":             "sidebar",
        "sidebar.right":            "sidebar-simple",
        "list.bullet":              "list-bullets",
        "list.dash":                "list-dashes",
        "square.grid.2x2":         "grid-four",
        "ellipsis":                 "dots-three",
        "ellipsis.vertical":        "dots-three-vertical",

        // Time
        "clock":                    "clock",

        // Storage & save
        "archivebox":               "archive-box",
        "tray":                     "tray",
        "floppy.disk":              "floppy-disk",
        "download":                 "download-simple",
        "upload":                   "upload-simple",
        "arrow.down.circle":        "arrow-circle-down",
        "arrow.up.circle":          "arrow-circle-up",

        // Misc
        "sun.max":                  "sun",
        "moon":                     "moon",
        "speaker.wave.2":           "speaker-high",
        "speaker.wave.1":           "speaker-low",
        "speaker.slash":            "speaker-slash",
        "hand.point.up":            "hand-pointing",
        "cursorarrow":              "cursor",
        "selection":                "selection",
        "note":                     "note",
        "note.text":                "note",
        "app.window":               "browser",
        "sort.up":                  "sort-ascending",
        "sort.down":                "sort-descending",
        "database":                 "database",
        "window":                   "browser",

        // Apple-specific → Phosphor equivalents
        "apple.logo":               "avocado",

        // Code
        "chevron.left.forwardslash.chevron.right": "code",
        "curlybraces":              "code",

        // Media controls (for menu bar / now playing)
        "play.fill":                "play",
        "pause.fill":               "pause",
        "backward.fill":            "skip-back",
        "forward.fill":             "skip-forward",
        "backward.end.fill":        "rewind",
        "forward.end.fill":         "fast-forward",
        "repeat":                   "repeat",
        "shuffle":                  "shuffle",
    ]
}
