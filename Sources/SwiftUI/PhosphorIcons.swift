/// Maps SF Symbols–style icon names to Phosphor Icons Unicode codepoints.
/// Font: Phosphor Regular (MIT license, https://phosphoricons.com)
public enum PhosphorIcons {

    /// Returns the Unicode character for a Phosphor icon, or nil if not mapped.
    public static func character(forName name: String) -> Character? {
        guard let scalar = codepoints[name] else { return nil }
        return Character(Unicode.Scalar(scalar)!)
    }

    // MARK: - Codepoint table

    static let codepoints: [String: UInt32] = [
        // Folders
        "folder":                   0xe24a,
        "folder.fill":              0xe24a,
        "folder.open":              0xe256,
        "folder.notch":             0xe24a,
        "folder.notch.open":        0xe256,

        // Files
        "doc":                      0xe230,
        "doc.fill":                 0xe230,
        "doc.text":                 0xe23a,
        "doc.text.fill":            0xe23a,
        "doc.richtext":             0xe23a,
        "file":                     0xe230,
        "file.text":                0xe23a,
        "file.code":                0xe914,
        "file.image":               0xea24,
        "file.audio":               0xea20,
        "file.video":               0xea22,
        "file.zip":                 0xe958,
        "file.pdf":                 0xe702,
        "file.css":                 0xeb34,
        "file.html":                0xeb38,
        "file.js":                  0xeb24,
        "file.ts":                  0xeb26,
        "file.py":                  0xeb2c,
        "file.rs":                  0xeb28,
        "file.doc":                 0xeb1e,

        // Navigation
        "house":                    0xe2c2,
        "house.fill":               0xe2c2,
        "house.simple":             0xe2c6,
        "chevron.left":             0xe138,
        "chevron.right":            0xe13a,
        "chevron.up":               0xe13c,
        "chevron.down":             0xe136,
        "arrow.left":               0xe058,
        "arrow.right":              0xe06c,
        "arrow.up":                 0xe08e,
        "arrow.down":               0xe03e,
        "arrow.clockwise":          0xe036,
        "arrow.counterclockwise":   0xe038,
        "arrow.up.left.and.arrow.down.right": 0xe0a6,
        "arrows.out":               0xe094,  // expand / maximize
        "arrows.in":                0xe08c,  // shrink / restore

        // Actions
        "magnifyingglass":          0xe30c,
        "plus":                     0xe3d4,
        "minus":                    0xe32a,
        "xmark":                    0xe4f6,
        "xmark.circle":             0xe4f6,
        "checkmark":                0xe182,
        "checkmark.circle":         0xe184,
        "pencil":                   0xe3ae,
        "pencil.simple":            0xe3b4,
        "trash":                    0xe4a6,
        "trash.fill":               0xe4a6,
        "trash.simple":             0xe4a8,
        "copy":                     0xe1ca,
        "clipboard":                0xe196,
        "share":                    0xe406,
        "share.network":            0xe408,
        "link":                     0xe2e2,
        "pin":                      0xe3e2,
        "bookmark":                 0xe0e8,
        "bookmark.fill":            0xe0ea,
        "tag":                      0xe478,
        "star":                     0xe46a,
        "star.fill":                0xe46a,
        "heart":                    0xe2a8,
        "heart.fill":               0xe2a8,

        // Info & warnings
        "info.circle":              0xe2ce,
        "info.circle.fill":         0xe2ce,
        "questionmark.circle":      0xe3e8,
        "exclamationmark.triangle": 0xe4e0,
        "exclamationmark.circle":   0xe4e2,

        // System
        "gear":                     0xe270,
        "gearshape":                0xe270,
        "gearshape.fill":           0xe272,
        "wrench":                   0xe5d4,
        "slider.horizontal.3":      0xe434,
        "paintbrush":               0xe6f0,
        "textformat":               0xe6ee,
        "terminal":                 0xe47e,
        "terminal.fill":            0xeae8,

        // Hardware & storage
        "desktopcomputer":          0xe560,
        "display":                  0xe32e,
        "internaldrive":            0xe29e,
        "externaldrive":            0xe2a0,
        "cpu":                      0xe610,
        "memorychip":               0xe610,
        "battery.100":              0xe4c0, // battery-full codepoint not found, using approximation
        "printer":                  0xe3dc,
        "plug":                     0xe946,

        // Media
        "photo":                    0xe2ca,
        "photo.fill":               0xe2cc,
        "music.note":               0xe33c,
        "music.note.list":          0xe340,
        "video":                    0xe4da,
        "video.fill":               0xe4da,

        // Communication
        "envelope":                 0xe214,
        "envelope.fill":            0xe214,
        "bubble.left":              0xe15c,
        "bubble.left.fill":         0xe17a,
        "bell":                     0xe0ce,
        "bell.fill":                0xe0ce,
        "person":                   0xe4c2,
        "person.fill":              0xe4c2,
        "person.2":                 0xe4d6,

        // Security
        "lock":                     0xe2fa,
        "lock.fill":                0xe2fa,
        "lock.open":                0xe306,
        "key":                      0xe2d6,
        "shield":                   0xe40a,
        "shield.checkered":         0xe40c,

        // Network & cloud
        "globe":                    0xe288,
        "network":                  0xe28e,
        "wifi":                     0xe4ea,
        "cloud":                    0xe1aa,
        "cloud.fill":               0xe1aa,
        "icloud":                   0xe1aa,

        // View controls
        "eye":                      0xe220,
        "eye.fill":                 0xe220,
        "eye.slash":                0xe224,
        "sidebar.left":             0xeab6,
        "sidebar.right":            0xec24,
        "list.bullet":              0xe2f2,
        "list.dash":                0xe2f0,
        "square.grid.2x2":         0xe464,
        "ellipsis":                 0xe1fe,
        "ellipsis.vertical":        0xe208,

        // Time
        "clock":                    0xe19a,
        "clock.fill":               0xe19a,

        // Storage & save
        "archivebox":               0xe00c,
        "archivebox.fill":          0xe00c,
        "tray":                     0xe20a,
        "tray.fill":                0xe4be,
        "floppy.disk":              0xe248,
        "download":                 0xe20a,
        "upload":                   0xe4be,
        "arrow.down.circle":        0xe20a,
        "arrow.up.circle":          0xe4be,

        // Misc
        "sun.max":                  0xe472,
        "sun.max.fill":             0xe472,
        "moon":                     0xe330,
        "moon.fill":                0xe330,
        "speaker.wave.2":           0xe44a,
        "speaker.wave.1":           0xe44c,
        "speaker.slash":            0xe45c,
        "hand.point.up":            0xe29a,
        "cursorarrow":              0xe1dc,
        "selection":                0xe69a,
        "note":                     0xe348,
        "note.text":                0xe34c,
        "app.window":               0xe5da,
        "sort.up":                  0xe444,
        "sort.down":                0xe446,
        "database":                 0xe1de,
        "apple.logo":               0xe516,
        "window":                   0xe5da,

        // Code-specific
        "chevron.left.forwardslash.chevron.right": 0xe1bc,
        "curlybraces":              0xe1bc,
    ]
}
