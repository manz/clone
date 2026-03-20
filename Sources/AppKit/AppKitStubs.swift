import Foundation

// MARK: - Minimal AppKit type stubs for compilation.
// On real macOS these come from Apple's AppKit. Clone's AppKit module shadows it,
// so we must provide stubs for types that app code references.

// MARK: - NSView

private let _zeroPoint = CGPoint()
private let _zeroSize = CGSize()
private let _zeroRect = CGRect()

open class NSView {
    public var wantsLayer: Bool = false
    public var frame: CGRect = _zeroRect
    public init() {}
    public init(frame: CGRect) { self.frame = frame }
}

// MARK: - NSWindow

open class NSWindow {
    public struct StyleMask: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let titled = StyleMask(rawValue: 1)
        public static let closable = StyleMask(rawValue: 2)
        public static let miniaturizable = StyleMask(rawValue: 4)
        public static let resizable = StyleMask(rawValue: 8)
        public static let fullScreen = StyleMask(rawValue: 1 << 14)
        public static let fullSizeContentView = StyleMask(rawValue: 1 << 15)
    }
    public var styleMask: StyleMask = []
    public var title: String = ""
    public var contentView: NSView?
    public init() {}
    public init(contentRect: CGRect, styleMask: StyleMask, backing: BackingStoreType = .buffered, defer flag: Bool = false) {
        self.styleMask = styleMask
    }
    public func makeKeyAndOrderFront(_ sender: Any?) {}
    public func close() {}
    public func center() {}
    public func setContentSize(_ size: CGSize) {}
    public func toggleFullScreen(_ sender: Any?) {}
    public var isVisible: Bool { false }
    public var collectionBehavior: CollectionBehavior = []
    public struct CollectionBehavior: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let fullScreenPrimary = CollectionBehavior(rawValue: 1)
    }
    public enum Level: Int { case normal, floating }
    public var level: Level = .normal
    public var backgroundColor: NSColor? = nil
    public var isOpaque: Bool = true
    public var hasShadow: Bool = true
    public var titlebarAppearsTransparent: Bool = false
    public var titleVisibility: TitleVisibility = .visible
    public enum TitleVisibility: Int { case visible, hidden }
    public enum BackingStoreType: Int { case buffered }
}

// MARK: - NSWindowDelegate

public protocol NSWindowDelegate: AnyObject {}

// MARK: - NSWindowController

open class NSWindowController {
    public var window: NSWindow?
    public init() {}
    public init(window: NSWindow) { self.window = window }
    public func showWindow(_ sender: Any?) {}
    public func close() {}
}

// MARK: - NSApplication

open class NSApplication {
    public static let shared = NSApplication()
    public func terminate(_ sender: Any?) {}
    public var windows: [NSWindow] = []
    public func activate(ignoringOtherApps: Bool) {}
    public var mainWindow: NSWindow? { nil }
    public var keyWindow: NSWindow? { nil }
}
public let NSApp: NSApplication = .shared

// MARK: - NSImage

open class NSImage {
    public var size: CGSize = _zeroSize
    public init() {}
    public init?(named: String) {}
    public init(size: CGSize) { self.size = size }
    public func lockFocus() {}
    public func unlockFocus() {}
}

// MARK: - NSBitmapImageRep

open class NSBitmapImageRep {
    public enum FileType: UInt { case png, jpeg, tiff }
    public struct PropertyKey: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let compressionFactor = PropertyKey(rawValue: "compressionFactor")
    }
    public init?(data: Data) {}
    public func representation(using fileType: FileType, properties: [PropertyKey: Any]) -> Data? { nil }
}

// MARK: - NSEvent

open class NSEvent {
    public var type: EventType = .keyDown
    public var modifierFlags: ModifierFlags = []
    public var keyCode: UInt16 = 0
    public var characters: String? = nil
    public var locationInWindow: CGPoint = _zeroPoint

    public enum EventType: UInt { case keyDown, keyUp, leftMouseDown, leftMouseUp, rightMouseDown, scrollWheel }
    public struct ModifierFlags: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let shift = ModifierFlags(rawValue: 1 << 17)
        public static let control = ModifierFlags(rawValue: 1 << 18)
        public static let option = ModifierFlags(rawValue: 1 << 19)
        public static let command = ModifierFlags(rawValue: 1 << 20)
    }

    public static func addLocalMonitorForEvents(matching mask: EventTypeMask, handler: @escaping (NSEvent) -> NSEvent?) -> Any? { nil }
    public static func removeMonitor(_ monitor: Any?) {}
    public var scrollingDeltaX: CGFloat { 0 }
    public var scrollingDeltaY: CGFloat { 0 }
    public struct EventTypeMask: OptionSet, Sendable {
        public let rawValue: UInt64
        public init(rawValue: UInt64) { self.rawValue = rawValue }
        public static let keyDown = EventTypeMask(rawValue: 1)
    }
}

// MARK: - NSScreen

open class NSScreen {
    public static var main: NSScreen? { NSScreen() }
    public static var screens: [NSScreen] = [NSScreen()]
    public var frame: CGRect = CGRect(origin: _zeroPoint, size: CGSize(width: 1920, height: 1080))
    public var visibleFrame: CGRect = CGRect(origin: _zeroPoint, size: CGSize(width: 1920, height: 1080))
    public var backingScaleFactor: CGFloat = 2.0
}

// MARK: - NSAlert

open class NSAlert {
    public enum Style: UInt { case warning, informational, critical }
    public var alertStyle: Style = .informational
    public var messageText: String = ""
    public var informativeText: String = ""
    public func addButton(withTitle: String) {}
    public func runModal() -> ModalResponse { .alertFirstButtonReturn }
    public init() {}

    public struct ModalResponse: RawRepresentable, Equatable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let alertFirstButtonReturn = ModalResponse(rawValue: 1000)
        public static let alertSecondButtonReturn = ModalResponse(rawValue: 1001)
    }
}

// MARK: - NSWorkspace

open class NSWorkspace {
    public static let shared = NSWorkspace()
    public var notificationCenter: NotificationCenter { .default }
    public static let didWakeNotification = Notification.Name("NSWorkspaceDidWake")
}

// MARK: - NSGraphicsContext

open class NSGraphicsContext {
    public static var current: NSGraphicsContext? { nil }
    public var cgContext: Any? { nil }
    public static func saveGraphicsState() {}
    public static func restoreGraphicsState() {}
}

// MARK: - NSCursor

open class NSCursor {
    public static let pointingHand = NSCursor()
    public static let arrow = NSCursor()
    public func push() {}
    public func pop() {}
    public static func pop() {}
}

// MARK: - NSPasteboard

open class NSPasteboard {
    public static let general = NSPasteboard()
    public func clearContents() {}
    public func setString(_ string: String, forType: PasteboardType) {}
    public struct PasteboardType: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let string = PasteboardType(rawValue: "public.utf8-plain-text")
        public static let fileURL = PasteboardType(rawValue: "public.file-url")
    }
}

// MARK: - NSTextField / NSSearchField / NSComboBox

open class NSTextField: NSView {
    public var stringValue: String = ""
    public var placeholderString: String?
    public var isEditable: Bool = true
    public var isBezeled: Bool = true
}

open class NSSearchField: NSTextField {}
open class NSComboBox: NSTextField {}

// MARK: - NSTextView

open class NSTextView: NSView {
    public var string: String = ""
    public var isEditable: Bool = true
}

// MARK: - NSHostingController

open class NSHostingController<Content> {
    public var view: NSView = NSView()
    public init(rootView: Content) {}
}

// MARK: - NSItemProvider

open class NSItemProvider {
    public init() {}
    public init(object: Any) {}
}
