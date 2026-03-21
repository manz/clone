import Foundation
import AudioBridge

public class AVPlayerItem: NSObject {
    public let asset: AVAsset
    public private(set) var duration: CMTime = .zero
    public private(set) var status: Status = .unknown

    public enum Status: Int { case unknown, readyToPlay, failed }

    /// Notification posted when the item finishes playing.
    public static let didPlayToEndTimeNotification = Notification.Name("AVPlayerItemDidPlayToEndTime")

    public init(url: URL) {
        self.asset = AVAsset(url: url)
        super.init()
        probe()
    }

    public init(asset: AVAsset) {
        self.asset = asset
        super.init()
        probe()
    }

    private func probe() {
        guard asset.url.isFileURL else {
            status = .failed
            return
        }
        do {
            let player = try AudioPlayer.open(path: asset.url.path, delegate: ProbeDelegate())
            let secs = player.duration()
            duration = CMTime(seconds: secs)
            status = .readyToPlay
        } catch {
            status = .failed
        }
    }

    internal func postDidPlayToEndTime() {
        NotificationCenter.default.post(name: Self.didPlayToEndTimeNotification, object: self)
    }
}

private final class ProbeDelegate: AudioPlayerDelegate, @unchecked Sendable {
    func onStateChanged(state: PlaybackState) {}
    func onTimeUpdate(currentSeconds: Double, durationSeconds: Double) {}
    func onDidFinishPlaying() {}
}
