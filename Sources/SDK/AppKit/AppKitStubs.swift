import Foundation
import CoreGraphics
@_exported import QuartzCore

// MARK: - Minimal AppKit type stubs for compilation.
// On real macOS these come from Apple's AppKit. Clone's AppKit module shadows it,
// so we must provide stubs for types that app code references.

// MARK: - NSResponder

open class NSResponder: NSObject {
    public override init() { super.init() }
}

// MARK: - NSView

private let _zeroPoint = CGPoint()
private let _zeroSize = CGSize()
private let _zeroRect = CGRect()

open class NSView: NSResponder {
    public var wantsLayer: Bool = false
    public var frame: CGRect = _zeroRect
    public override init() { super.init() }
    public init(frame: CGRect) { self.frame = frame; super.init() }
    open func hitTest(_ point: CGPoint) -> NSView? { nil }
    public var subviews: [NSView] = []
    public func addSubview(_ view: NSView) {}
    public func removeFromSuperview() {}
    public var bounds: CGRect = _zeroRect
    public var needsDisplay: Bool = false
    public var layer: CALayer? = nil
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
    public var isMovableByWindowBackground: Bool = false
    public weak var delegate: NSWindowDelegate?
    public var contentViewController: NSViewController?
    public var minSize: CGSize = _zeroSize
    public var maxSize: CGSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    public var isReleasedWhenClosed: Bool = true
    public var animationBehavior: AnimationBehavior = .default
    public enum AnimationBehavior: Int { case `default`, none, documentWindow, utilityWindow, alertPanel }
    public func setFrameOrigin(_ origin: CGPoint) {}
    public func setFrame(_ rect: CGRect, display: Bool, animate: Bool = false) {}
    public var frame: CGRect = _zeroRect
    public func orderFront(_ sender: Any?) {}
    public func orderOut(_ sender: Any?) {}
    public var screen: NSScreen? { .main }
    public var firstResponder: NSResponder? { nil }
}

// MARK: - NSViewController

open class NSViewController {
    public var view: NSView = NSView()
    public init() {}
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

open class NSApplication: @unchecked Sendable {
    nonisolated(unsafe) public static let shared = NSApplication()
    public func terminate(_ sender: Any?) {}
    public var windows: [NSWindow] = []
    public func activate(ignoringOtherApps: Bool) {}
    public var mainWindow: NSWindow? { nil }
    public var keyWindow: NSWindow? { nil }
    public var currentEvent: NSEvent? { nil }
    public var isActive: Bool { true }
    @discardableResult
    public func setActivationPolicy(_ policy: ActivationPolicy) -> Bool { true }
    public enum ActivationPolicy: Int { case regular, accessory, prohibited }

    public static let didBecomeActiveNotification = Notification.Name("NSApplicationDidBecomeActive")
    public static let willTerminateNotification = Notification.Name("NSApplicationWillTerminate")
    public static let didFinishLaunchingNotification = Notification.Name("NSApplicationDidFinishLaunching")
    public static let willResignActiveNotification = Notification.Name("NSApplicationWillResignActive")
    public static let didHideNotification = Notification.Name("NSApplicationDidHide")
    public static let didUnhideNotification = Notification.Name("NSApplicationDidUnhide")
    public static let willBecomeActiveNotification = Notification.Name("NSApplicationWillBecomeActive")
}
nonisolated(unsafe) public let NSApp: NSApplication = .shared

// MARK: - NSImage

open class NSImage: NSObject, @unchecked Sendable, NSItemProviderReading, NSItemProviderWriting {
    public static var readableTypeIdentifiersForItemProvider: [String] { ["public.image"] }
    public required convenience init(itemProviderData data: Data, typeIdentifier: String) throws { self.init() }
    public static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> Self { try self.init(itemProviderData: data, typeIdentifier: typeIdentifier) }
    public static var writableTypeIdentifiersForItemProvider: [String] { ["public.image"] }
    public func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping @Sendable (Data?, Error?) -> Void) -> Progress? { completionHandler(nil, nil); return nil }
    // NSImage properties and methods
    public var size: CGSize = _zeroSize
    public override init() { super.init() }
    public init?(named: String) {}
    public init(size: CGSize) { self.size = size }
    public init?(data: Data) {}
    public init(cgImage: CGImage, size: CGSize) { self.size = size }
    public func lockFocus() {}
    public func unlockFocus() {}
    public func cgImage(forProposedRect proposedRect: UnsafeMutablePointer<CGRect>?, context: Any?, hints: [NSImageRep.HintKey: Any]?) -> CGImage? { nil }
    public var tiffRepresentation: Data? { nil }
    public func draw(in rect: CGRect) {}
    public func draw(in rect: CGRect, from: CGRect, operation: CompositingOperation, fraction: CGFloat) {}
    public func addRepresentation(_ rep: NSImageRep) {}
    public var representations: [NSImageRep] = []
    public enum CompositingOperation: UInt { case sourceOver, copy }
}

// NSImage drag/drop: on real macOS, NSImage conforms to NSItemProviderReading/Writing.
// Clone's stub NSImage isn't NSObject-based so can't conform to those ObjC protocols.
// Apps using `canLoadObject(ofClass: NSImage.self)` will need `#if canImport(CloneClient)` guards.

// MARK: - NSImageRep

open class NSImageRep {
    public struct HintKey: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
    }
}

// MARK: - NSBitmapImageRep

open class NSBitmapImageRep: NSImageRep {
    public enum FileType: UInt { case png, jpeg, tiff }
    public struct PropertyKey: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let compressionFactor = PropertyKey(rawValue: "compressionFactor")
    }
    public init?(data: Data) {}
    public init?(bitmapDataPlanes planes: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>?, pixelsWide width: Int, pixelsHigh height: Int, bitsPerSample bps: Int, samplesPerPixel spp: Int, hasAlpha alpha: Bool, isPlanar: Bool, colorSpaceName: NSColorSpaceName, bytesPerRow rBytes: Int, bitsPerPixel pBits: Int) {}
    public func representation(using fileType: FileType, properties: [PropertyKey: Any]) -> Data? { nil }
    public var cgImage: CGImage? { nil }
}

/// NSColorSpaceName — string constants for color space names.
public struct NSColorSpaceName: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let deviceRGB = NSColorSpaceName(rawValue: "NSDeviceRGBColorSpace")
    public static let calibratedRGB = NSColorSpaceName(rawValue: "NSCalibratedRGBColorSpace")
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

    public static var modifierFlags: ModifierFlags { ModifierFlags(rawValue: 0) }

    public static func addLocalMonitorForEvents(matching mask: EventTypeMask, handler: @escaping (NSEvent) -> NSEvent?) -> Any? { nil }
    public static func removeMonitor(_ monitor: Any?) {}
    public var scrollingDeltaX: CGFloat { 0 }
    public var scrollingDeltaY: CGFloat { 0 }
    public struct EventTypeMask: OptionSet, Sendable {
        public let rawValue: UInt64
        public init(rawValue: UInt64) { self.rawValue = rawValue }
        public static let keyDown = EventTypeMask(rawValue: 1)
        public static let scrollWheel = EventTypeMask(rawValue: 2)
    }
}

// MARK: - NSScreen

open class NSScreen {
    public static var main: NSScreen? { NSScreen() }
    nonisolated(unsafe) public static var screens: [NSScreen] = [NSScreen()]
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

open class NSWorkspace: @unchecked Sendable {
    nonisolated(unsafe) public static let shared = NSWorkspace()
    public var notificationCenter: NotificationCenter { .default }
    public static let didWakeNotification = Notification.Name("NSWorkspaceDidWake")

    /// Open a file URL with the default application.
    /// On Clone, sends `.openFile` to the compositor which queries launchservicesd.
    @discardableResult
    open func open(_ url: URL) -> Bool {
        _openFileHandler?(url.path) ?? false
    }

    /// Open a file at the given path with the default application.
    @discardableResult
    open func openFile(_ fullPath: String) -> Bool {
        _openFileHandler?(fullPath) ?? false
    }
}

/// Internal handler wired by App.main() to send .openFile over IPC.
nonisolated(unsafe) public var _openFileHandler: ((String) -> Bool)?


// MARK: - NSGraphicsContext

open class NSGraphicsContext {
    nonisolated(unsafe) public static var current: NSGraphicsContext? = nil
    public var cgContext: Any? { nil }
    public static func saveGraphicsState() {}
    public static func restoreGraphicsState() {}
    public init() {}
    public init?(bitmapImageRep: NSBitmapImageRep) {}
}

// MARK: - NSCursor

open class NSCursor: @unchecked Sendable {
    nonisolated(unsafe) public static let pointingHand = NSCursor()
    nonisolated(unsafe) public static let arrow = NSCursor()
    public func push() {}
    public func pop() {}
    public static func pop() {}
}

// MARK: - NSPasteboard

open class NSPasteboard: @unchecked Sendable {
    nonisolated(unsafe) public static let general = NSPasteboard()
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

open class NSHostingController<Content>: NSViewController {
    public init(rootView: Content) { super.init() }
}

// MARK: - NSItemProvider
// NSItemProvider is provided by Foundation — no stub needed.

// MARK: - UTType stubs (Linux only — macOS has UniformTypeIdentifiers)

#if !canImport(UniformTypeIdentifiers)
public struct UTType: Hashable, Sendable {
    public let identifier: String
    public init(_ identifier: String) { self.identifier = identifier }

    public static let fileURL = UTType("public.file-url")
    public static let url = UTType("public.url")
    public static let image = UTType("public.image")
    public static let png = UTType("public.png")
    public static let jpeg = UTType("public.jpeg")
    public static let audio = UTType("public.audio")
    public static let mp3 = UTType("public.mp3")
    public static let mpeg4Audio = UTType("public.mpeg-4-audio")
    public static let movie = UTType("public.movie")
    public static let text = UTType("public.plain-text")
    public static let data = UTType("public.data")
    public static let json = UTType("public.json")
}
#endif

// MARK: - AVKit stubs (Linux only — macOS has real AVKit)

#if !canImport(AVKit)
open class AVRoutePickerView: NSView {
    public var isRoutePickerButtonBordered: Bool = true
    public var prioritizesVideoDevices: Bool = false
    public override init() { super.init() }
}
#endif

// MARK: - NSTextContentType

public struct NSTextContentType: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let username = NSTextContentType(rawValue: "username")
    public static let password = NSTextContentType(rawValue: "password")
    public static let newPassword = NSTextContentType(rawValue: "newPassword")
    public static let oneTimeCode = NSTextContentType(rawValue: "oneTimeCode")
    public static let emailAddress = NSTextContentType(rawValue: "emailAddress")
    public static let URL = NSTextContentType(rawValue: "URL")
    public static let name = NSTextContentType(rawValue: "name")
}

// MARK: - NSRect (alias for CGRect)

public typealias NSRect = CGRect
public typealias NSPoint = CGPoint
public typealias NSSize = CGSize

