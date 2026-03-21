// Aquax SDK stub: MediaPlayer
// No-op now playing and remote command types for compilation.
import Foundation

public final class MPNowPlayingInfoCenter: @unchecked Sendable {
    nonisolated(unsafe) private static let _shared = MPNowPlayingInfoCenter()
    public class func `default`() -> MPNowPlayingInfoCenter { _shared }
    public var nowPlayingInfo: [String: Any]?
    public var playbackState: MPNowPlayingPlaybackState = .unknown
}

public enum MPNowPlayingPlaybackState: UInt {
    case unknown, playing, paused, stopped, interrupted
}

public final class MPRemoteCommandCenter: @unchecked Sendable {
    public static func shared() -> MPRemoteCommandCenter { _shared }
    nonisolated(unsafe) private static let _shared = MPRemoteCommandCenter()

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
}

public class MPRemoteCommand {
    public var isEnabled: Bool = true
    @discardableResult
    public func addTarget(handler: @escaping (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus) -> Any {
        NSObject()
    }
    public func removeTarget(_ target: Any?) {}
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
