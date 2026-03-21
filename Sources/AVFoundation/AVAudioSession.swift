import Foundation

/// No-op shim — CPAL handles device selection internally.
public final class AVAudioSession: NSObject, @unchecked Sendable {
    nonisolated(unsafe) public static let sharedInstance = AVAudioSession()

    public enum Category: String, Sendable { case playback, ambient, soloAmbient, record, playAndRecord, multiRoute }
    public enum Mode: String, Sendable { case `default`, voiceChat, videoChat, gameChat, measurement, moviePlayback, spokenAudio }
    public struct CategoryOptions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let mixWithOthers = CategoryOptions(rawValue: 1)
        public static let duckOthers = CategoryOptions(rawValue: 2)
        public static let allowBluetooth = CategoryOptions(rawValue: 4)
    }

    public func setCategory(_ category: Category, mode: Mode = .default, options: CategoryOptions = []) throws {}
    public func setActive(_ active: Bool) throws {}
    public func setActive(_ active: Bool, options: SetActiveOptions = []) throws {}

    public struct SetActiveOptions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let notifyOthersOnDeactivation = SetActiveOptions(rawValue: 1)
    }
}
