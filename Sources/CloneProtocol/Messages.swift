import Foundation

/// Socket path for the compositor (XDG_RUNTIME_DIR on Linux, /tmp fallback on macOS).
public let compositorSocketPath: String = {
    let base = ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"] ?? "/tmp"
    return "\(base)/clone-compositor.sock"
}()

// MARK: - Render command (Codable, shared between processes)

public struct IPCColor: Codable, Equatable, Sendable {
    public let r: Float, g: Float, b: Float, a: Float
    public init(r: Float, g: Float, b: Float, a: Float) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }
}

public enum IPCFontWeight: String, Codable, Sendable {
    case regular, medium, semibold, bold
}

public enum IPCRenderCommand: Codable, Sendable {
    case rect(x: Float, y: Float, w: Float, h: Float, color: IPCColor)
    case roundedRect(x: Float, y: Float, w: Float, h: Float, radius: Float, color: IPCColor)
    case text(x: Float, y: Float, content: String, fontSize: Float, color: IPCColor, weight: IPCFontWeight, isIcon: Bool = false, maxWidth: Float? = nil)
    case shadow(x: Float, y: Float, w: Float, h: Float, radius: Float, blur: Float, color: IPCColor, ox: Float, oy: Float)
    case pushClip(x: Float, y: Float, w: Float, h: Float, radius: Float)
    case popClip
    case image(textureId: UInt64, x: Float, y: Float, w: Float, h: Float)
    case registerTexture(textureId: UInt64, width: UInt32, height: UInt32, rgbaData: [UInt8])
    case unregisterTexture(textureId: UInt64)
}

// MARK: - Surface types

/// How the compositor treats a surface.
public enum SurfaceRole: String, Codable, Sendable {
    /// Normal app window — gets chrome (title bar, traffic lights, shadow), draggable, resizable.
    case window
    /// Dock — pinned to bottom, above all windows, no chrome.
    case dock
    /// Menu bar — pinned to top, topmost, no chrome.
    case menubar
    /// Login window — fullscreen, no chrome, gates user session.
    case loginWindow
}

// MARK: - App menus

/// A single menu item within an app menu.
public struct AppMenuItem: Codable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var shortcut: String?
    public var isSeparator: Bool

    public init(id: String, title: String, shortcut: String? = nil, isSeparator: Bool = false) {
        self.id = id; self.title = title; self.shortcut = shortcut; self.isSeparator = isSeparator
    }

    public static func separator() -> AppMenuItem {
        AppMenuItem(id: "sep", title: "", isSeparator: true)
    }
}

/// A top-level menu (e.g. "File", "Edit") with its dropdown items.
public struct AppMenu: Codable, Sendable, Equatable {
    public var title: String
    public var items: [AppMenuItem]

    public init(title: String, items: [AppMenuItem]) {
        self.title = title; self.items = items
    }
}

// MARK: - Messages: App → Compositor

public enum AppMessage: Codable, Sendable {
    /// App registers itself. Role determines how the compositor handles the surface.
    case register(appId: String, title: String, width: Float, height: Float, role: SurfaceRole)
    /// App sends its render commands for the current frame.
    case frame(commands: [IPCRenderCommand])
    /// App requests to update its window title.
    case setTitle(title: String)
    /// App requests to close its window.
    case close
    /// App handled a tap at the given coordinates.
    case tapHandled
    /// Dock requests the compositor to launch an app binary.
    case launchApp(appId: String)
    /// Dock requests the compositor to restore a minimized window.
    case restoreApp(appId: String)
    /// App registers its menu bar menus.
    case registerMenus(menus: [AppMenu])
    /// App requests an open-file dialog.
    case showOpenPanel(allowedTypes: [String])
    /// MenuBar tells compositor a menu item was clicked for the focused app.
    case menuAction(itemId: String)
    /// LoginWindow tells compositor authentication succeeded — start user session.
    case sessionReady
}

// MARK: - Messages: Compositor → App

public enum CompositorMessage: Codable, Sendable {
    /// Surface was created with the given ID and size.
    case windowCreated(windowId: UInt64, width: Float, height: Float)
    /// Surface was resized.
    case resize(width: Float, height: Float)
    /// Request a frame render — app should respond with .frame
    case requestFrame(width: Float, height: Float)
    /// Pointer moved (local coordinates for windows, screen coordinates for dock/menubar).
    case pointerMove(x: Float, y: Float)
    /// Pointer button event.
    case pointerButton(button: UInt32, pressed: Bool, x: Float, y: Float)
    /// Key event.
    case key(keycode: UInt32, pressed: Bool)
    /// Compositor tells the app which app is focused (for menubar display).
    case focusedApp(name: String)
    /// Compositor tells the dock which apps have minimized windows.
    case minimizedApps(appIds: [String])
    /// Character typed (translated from keycode).
    case keyChar(character: String)
    /// Scroll wheel event (deltaX, deltaY in points).
    case scroll(deltaX: Float, deltaY: Float)
    /// System color scheme changed (resolved value from compositor).
    case colorScheme(dark: Bool)
    /// Compositor sends the focused app's menus to the menubar.
    case appMenus(appName: String, menus: [AppMenu])
    /// A menu item was selected (forwarded from menubar to the focused app).
    case menuAction(itemId: String)
    /// Result of an open-file dialog.
    case openPanelResult(path: String?)
    /// Compositor tells the app its window was closed (app decides whether to stay alive).
    case windowClosed
    /// Compositor tells the app to terminate (Cmd+Q / Quit menu).
    case terminate
}

// MARK: - Daemon (now-playing service)

/// Socket path for the now-playing daemon.
public let daemonSocketPath: String = {
    let base = ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"] ?? "/tmp"
    return "\(base)/clone-daemon.sock"
}()

/// Typed now-playing info (Codable replacement for [String: Any] in MPNowPlayingInfoCenter).
public struct NowPlayingInfo: Codable, Sendable, Equatable {
    public var title: String?
    public var artist: String?
    public var albumTitle: String?
    public var playbackDuration: Double?
    public var elapsedPlaybackTime: Double?
    public var playbackRate: Double?  // 0 = paused, 1 = playing
    public var appId: String

    public init(
        title: String? = nil, artist: String? = nil, albumTitle: String? = nil,
        playbackDuration: Double? = nil, elapsedPlaybackTime: Double? = nil,
        playbackRate: Double? = nil, appId: String
    ) {
        self.title = title
        self.artist = artist
        self.albumTitle = albumTitle
        self.playbackDuration = playbackDuration
        self.elapsedPlaybackTime = elapsedPlaybackTime
        self.playbackRate = playbackRate
        self.appId = appId
    }
}

/// Remote transport commands for media control.
public enum RemoteCommand: String, Codable, Sendable {
    case play, pause, togglePlayPause, nextTrack, previousTrack
}

/// Client → Daemon
public enum DaemonRequest: Codable, Sendable {
    case publishNowPlaying(NowPlayingInfo)
    case clearNowPlaying
    case remoteCommand(RemoteCommand)   // MenuBar sends this
    case observe                         // MenuBar subscribes to updates
}

/// Daemon → Client
public enum DaemonResponse: Codable, Sendable {
    case nowPlayingChanged(NowPlayingInfo?)
    case remoteCommand(RemoteCommand)    // Daemon forwards to owning app
}

// MARK: - Keychain service

/// Socket path for the keychain daemon.
public let keychainSocketPath: String = {
    let base = ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"] ?? "/tmp"
    return "\(base)/clone-keychain.sock"
}()

/// Keychain item class (maps to kSecClass values).
public enum SecItemClass: String, Codable, Sendable {
    case internetPassword
    case genericPassword
    case certificate
    case key
    case identity
}

/// A keychain item.
public struct KeychainItem: Codable, Sendable, Equatable {
    public var itemClass: SecItemClass
    public var service: String?
    public var account: String?
    public var server: String?
    public var label: String?
    public var valueData: Data?
    public var accessGroup: String?
    public var appId: String
    public var creationDate: Date
    public var modificationDate: Date

    public init(
        itemClass: SecItemClass,
        service: String? = nil,
        account: String? = nil,
        server: String? = nil,
        label: String? = nil,
        valueData: Data? = nil,
        accessGroup: String? = nil,
        appId: String,
        creationDate: Date = Date(),
        modificationDate: Date = Date()
    ) {
        self.itemClass = itemClass
        self.service = service
        self.account = account
        self.server = server
        self.label = label
        self.valueData = valueData
        self.accessGroup = accessGroup
        self.appId = appId
        self.creationDate = creationDate
        self.modificationDate = modificationDate
    }
}

/// Query for searching keychain items.
public struct KeychainSearchQuery: Codable, Sendable {
    public var itemClass: SecItemClass?
    public var service: String?
    public var account: String?
    public var server: String?
    public var matchLimit: MatchLimit
    public var returnData: Bool

    public enum MatchLimit: String, Codable, Sendable {
        case one, all
    }

    public init(
        itemClass: SecItemClass? = nil,
        service: String? = nil,
        account: String? = nil,
        server: String? = nil,
        matchLimit: MatchLimit = .one,
        returnData: Bool = true
    ) {
        self.itemClass = itemClass
        self.service = service
        self.account = account
        self.server = server
        self.matchLimit = matchLimit
        self.returnData = returnData
    }
}

/// Client → Keychain daemon
public enum KeychainRequest: Codable, Sendable {
    case add(KeychainItem)
    case search(KeychainSearchQuery)
    case update(query: KeychainSearchQuery, attributes: KeychainItem)
    case delete(KeychainSearchQuery)
}

/// Keychain daemon → Client
public enum KeychainResponse: Codable, Sendable {
    case success
    case item(KeychainItem)
    case items([KeychainItem])
    case error(KeychainErrorCode)
}

/// Error codes matching Apple's Security framework errSec* constants.
public enum KeychainErrorCode: Int32, Codable, Sendable {
    case success = 0
    case itemNotFound = -25300
    case duplicateItem = -25299
    case authFailed = -25293
    case interactionNotAllowed = -25308
    case decode = -26275
    case param = -50
    case unimplemented = -4
}

// MARK: - Wire format: 4-byte length prefix + JSON

public enum WireProtocol {
    public static func encode<T: Encodable>(_ message: T) throws -> Data {
        let json = try JSONEncoder().encode(message)
        var length = UInt32(json.count).bigEndian
        var data = Data(bytes: &length, count: 4)
        data.append(json)
        return data
    }

    public static func decode<T: Decodable>(_ type: T.Type, from buffer: Data) -> (T, Int)? {
        guard buffer.count >= 4 else { return nil }
        let length = buffer.withUnsafeBytes {
            $0.load(as: UInt32.self).bigEndian
        }
        let totalLength = 4 + Int(length)
        guard buffer.count >= totalLength else { return nil }
        let jsonData = buffer.subdata(in: 4..<totalLength)
        guard let message = try? JSONDecoder().decode(T.self, from: jsonData) else { return nil }
        return (message, totalLength)
    }
}
