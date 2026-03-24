// Aquax SDK: MediaPlayer
// Now-playing and remote command types, wired to the cloned daemon.
import Foundation
import PosixShim
import CloneProtocol

// MARK: - Daemon client (internal)

/// Connects to the cloned daemon for now-playing IPC.
final class DaemonClient: @unchecked Sendable {
    private var socketFd: Int32 = -1
    private var readBuffer = Data()
    private var readSource: DispatchSourceRead?
    private let ioQueue = DispatchQueue(label: "clone.daemon.client", qos: .userInitiated)
    private let lock = NSLock()
    private(set) var isConnected = false

    /// Called on ioQueue when the daemon sends a response.
    var onResponse: ((DaemonResponse) -> Void)?

    func connect() -> Bool {
        socketFd = socket(AF_UNIX, CLONE_SOCK_STREAM, 0)
        guard socketFd >= 0 else { return false }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        daemonSocketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) { pathPtr in
                pathPtr.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
                    _ = strlcpy(dest, ptr, 104)
                }
            }
        }

        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                posix_connect(socketFd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else {
            posix_close(socketFd)
            socketFd = -1
            return false
        }

        isConnected = true

        // Start async read loop
        let flags = fcntl(socketFd, F_GETFL)
        _ = fcntl(socketFd, F_SETFL, flags | O_NONBLOCK)

        let source = DispatchSource.makeReadSource(fileDescriptor: socketFd, queue: ioQueue)
        source.setEventHandler { [weak self] in
            self?.handleReadable()
        }
        source.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.socketFd >= 0 {
                posix_close(self.socketFd)
                self.socketFd = -1
            }
            self.isConnected = false
        }
        source.resume()
        readSource = source

        return true
    }

    func send(_ request: DaemonRequest) {
        guard isConnected, let data = try? WireProtocol.encode(request) else { return }
        data.withUnsafeBytes { ptr in
            _ = posix_write(socketFd, ptr.baseAddress!, data.count)
        }
    }

    private func handleReadable() {
        var buf = [UInt8](repeating: 0, count: 65536)
        let bytesRead = posix_read(socketFd, &buf, buf.count)
        guard bytesRead > 0 else {
            readSource?.cancel()
            readSource = nil
            isConnected = false
            return
        }

        lock.lock()
        readBuffer.append(contentsOf: buf[0..<bytesRead])
        while let (msg, consumed) = WireProtocol.decode(DaemonResponse.self, from: readBuffer) {
            readBuffer = readBuffer.subdata(in: consumed..<readBuffer.count)
            lock.unlock()
            onResponse?(msg)
            lock.lock()
        }
        lock.unlock()
    }

    func disconnect() {
        readSource?.cancel()
        readSource = nil
        if socketFd >= 0 {
            posix_close(socketFd)
            socketFd = -1
        }
        isConnected = false
    }
}

// MARK: - MPNowPlayingInfoCenter

public final class MPNowPlayingInfoCenter: @unchecked Sendable {
    nonisolated(unsafe) private static let _shared = MPNowPlayingInfoCenter()
    public class func `default`() -> MPNowPlayingInfoCenter { _shared }

    private let daemonClient = DaemonClient()
    private let lock = NSLock()

    /// App identifier — set automatically from process name.
    var _appId: String = ProcessInfo.processInfo.processName

    public var playbackState: MPNowPlayingPlaybackState = .unknown {
        didSet { publishIfNeeded() }
    }

    public var nowPlayingInfo: [String: Any]? {
        didSet { publishIfNeeded() }
    }

    private func ensureConnected() {
        guard !daemonClient.isConnected else { return }
        _ = daemonClient.connect()
    }

    private func publishIfNeeded() {
        guard let info = nowPlayingInfo else {
            ensureConnected()
            daemonClient.send(.clearNowPlaying)
            return
        }

        let rate: Double
        switch playbackState {
        case .playing: rate = 1.0
        case .paused, .stopped, .interrupted, .unknown: rate = 0.0
        }

        let nowPlaying = NowPlayingInfo(
            title: info[MPMediaItemPropertyTitle] as? String,
            artist: info[MPMediaItemPropertyArtist] as? String,
            albumTitle: info[MPMediaItemPropertyAlbumTitle] as? String,
            playbackDuration: info[MPMediaItemPropertyPlaybackDuration] as? Double,
            elapsedPlaybackTime: info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double,
            playbackRate: (info[MPNowPlayingInfoPropertyPlaybackRate] as? Double) ?? rate,
            appId: _appId
        )

        ensureConnected()
        daemonClient.send(.publishNowPlaying(nowPlaying))
    }
}

public enum MPNowPlayingPlaybackState: UInt {
    case unknown, playing, paused, stopped, interrupted
}

// MARK: - MPRemoteCommandCenter

public final class MPRemoteCommandCenter: @unchecked Sendable {
    public static func shared() -> MPRemoteCommandCenter { _shared }
    nonisolated(unsafe) private static let _shared = MPRemoteCommandCenter()

    private let daemonClient = DaemonClient()
    private var listening = false

    public let playCommand = MPRemoteCommand()
    public let pauseCommand = MPRemoteCommand()
    public let togglePlayPauseCommand = MPRemoteCommand()
    public let nextTrackCommand = MPRemoteCommand()
    public let previousTrackCommand = MPRemoteCommand()
    public let changePlaybackPositionCommand = MPRemoteCommand()
    public let skipForwardCommand = MPSkipIntervalCommand()
    public let skipBackwardCommand = MPSkipIntervalCommand()
    public let seekForwardCommand = MPRemoteCommand()
    public let seekBackwardCommand = MPRemoteCommand()
    public let likeCommand = MPFeedbackCommand()
    public let dislikeCommand = MPFeedbackCommand()

    /// Start listening for remote commands from the daemon.
    /// Called automatically when the first handler is registered.
    func startListeningIfNeeded() {
        guard !listening else { return }
        guard daemonClient.connect() else { return }
        listening = true

        daemonClient.onResponse = { [weak self] response in
            guard let self else { return }
            if case .remoteCommand(let cmd) = response {
                self._dispatch(command: cmd)
            }
        }
    }

    func _dispatch(command: RemoteCommand) {
        let event = MPRemoteCommandEvent()
        switch command {
        case .play:
            playCommand.fire(event)
        case .pause:
            pauseCommand.fire(event)
        case .togglePlayPause:
            togglePlayPauseCommand.fire(event)
        case .nextTrack:
            nextTrackCommand.fire(event)
        case .previousTrack:
            previousTrackCommand.fire(event)
        }
    }
}

// MARK: - MPRemoteCommand

public class MPRemoteCommand {
    public var isEnabled: Bool = true
    private var handlers: [(MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus] = []

    @discardableResult
    public func addTarget(handler: @escaping (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus) -> Any {
        handlers.append(handler)
        // Trigger listening when first handler is added
        MPRemoteCommandCenter.shared().startListeningIfNeeded()
        return NSObject()
    }

    public func removeTarget(_ target: Any?) {
        handlers.removeAll()
    }

    func fire(_ event: MPRemoteCommandEvent) {
        guard isEnabled else { return }
        for handler in handlers {
            _ = handler(event)
        }
    }
}

public class MPSkipIntervalCommand: MPRemoteCommand {
    public var preferredIntervals: [NSNumber] = []
}

public class MPFeedbackCommand: MPRemoteCommand {
    public var isActive: Bool = false
}

public class MPRemoteCommandEvent {
    public var timestamp: TimeInterval { 0 }
}

public class MPChangePlaybackPositionCommandEvent: MPRemoteCommandEvent {
    public var positionTime: TimeInterval { 0 }
}

public class MPSkipIntervalCommandEvent: MPRemoteCommandEvent {
    public var interval: TimeInterval { 0 }
}

public enum MPRemoteCommandHandlerStatus: Int {
    case success, noSuchContent, noActionableNowPlayingItem, deviceNotFound, commandFailed
}

// Now playing info property keys
public let MPMediaItemPropertyTitle = "title"
public let MPMediaItemPropertyArtist = "artist"
public let MPMediaItemPropertyAlbumTitle = "albumTitle"
public let MPMediaItemPropertyPlaybackDuration = "playbackDuration"
public let MPNowPlayingInfoPropertyElapsedPlaybackTime = "elapsedPlaybackTime"
public let MPNowPlayingInfoPropertyPlaybackRate = "playbackRate"
public let MPMediaItemPropertyArtwork = "artwork"

public class MPMediaItemArtwork {
    public init(boundsSize: CGSize, requestHandler: @escaping (CGSize) -> Any) {}
}
