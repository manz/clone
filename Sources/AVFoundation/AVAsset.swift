import Foundation
import AudioBridge

public class AVAsset: NSObject {
    internal let url: URL
    private var _duration: CMTime = .zero

    public var duration: CMTime { _duration }

    public init(url: URL) {
        self.url = url
        super.init()
        probeMetadata()
    }

    private func probeMetadata() {
        guard url.isFileURL else { return }
        do {
            let player = try AudioPlayer.open(path: url.path, delegate: NoOpDelegate())
            let secs = player.duration()
            _duration = CMTime(seconds: secs)
        } catch {
            // Cannot probe — duration stays zero
        }
    }
}

/// Internal delegate used only for metadata probing.
private final class NoOpDelegate: AudioPlayerDelegate, @unchecked Sendable {
    func onStateChanged(state: PlaybackState) {}
    func onTimeUpdate(currentSeconds: Double, durationSeconds: Double) {}
    func onDidFinishPlaying() {}
}
