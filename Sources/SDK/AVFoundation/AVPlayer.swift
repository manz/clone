import Foundation
import AudioBridge

/// Token returned by addPeriodicTimeObserver, used to removeTimeObserver.
public class TimeObserverToken {
    internal let id: UInt64
    internal init(id: UInt64) { self.id = id }
}

public class AVPlayer: NSObject {
    public var rate: Float = 0
    public private(set) var currentItem: AVPlayerItem?

    private var rustPlayer: AudioPlayer?
    private var delegateAdapter: PlayerDelegateAdapter?

    private var timeObservers: [(id: UInt64, queue: DispatchQueue?, block: (CMTime) -> Void)] = []
    private var nextObserverId: UInt64 = 0

    public override init() {
        super.init()
    }

    public init(url: URL) {
        super.init()
        let item = AVPlayerItem(url: url)
        replaceCurrentItem(with: item)
    }

    public init(playerItem item: AVPlayerItem?) {
        super.init()
        if let item {
            replaceCurrentItem(with: item)
        }
    }

    public func play() {
        guard let rp = rustPlayer else { return }
        do {
            try rp.play()
            rate = 1
        } catch {
            // Play failed — stay paused
        }
    }

    public func pause() {
        rustPlayer?.pause()
        rate = 0
    }

    public func seek(to time: CMTime) {
        try? rustPlayer?.seek(seconds: time.seconds)
    }

    public func seek(to time: CMTime, completionHandler: @escaping (Bool) -> Void) {
        do {
            try rustPlayer?.seek(seconds: time.seconds)
            completionHandler(true)
        } catch {
            completionHandler(false)
        }
    }

    public func replaceCurrentItem(with item: AVPlayerItem?) {
        // Stop current playback
        rustPlayer?.stop()
        rustPlayer = nil
        delegateAdapter = nil
        rate = 0

        currentItem = item
        guard let item else { return }

        // Create a new Rust AudioPlayer for this item
        let adapter = PlayerDelegateAdapter(player: self, item: item)
        delegateAdapter = adapter

        do {
            let rp = try AudioPlayer.open(path: item.asset.url.path, delegate: adapter)
            rustPlayer = rp
        } catch {
            // Failed to open — item status already reflects this from probe
        }
    }

    public var automaticallyWaitsToMinimizeStalling: Bool = true
    public var allowsExternalPlayback: Bool = true
    public var volume: Float = 1.0

    public func currentTime() -> CMTime {
        guard let rp = rustPlayer else { return .zero }
        return CMTime(seconds: rp.currentTime())
    }

    public func addPeriodicTimeObserver(
        forInterval interval: CMTime,
        queue: DispatchQueue?,
        using block: @escaping (CMTime) -> Void
    ) -> Any {
        let id = nextObserverId
        nextObserverId += 1
        timeObservers.append((id: id, queue: queue, block: block))
        return TimeObserverToken(id: id)
    }

    public func removeTimeObserver(_ observer: Any) {
        guard let token = observer as? TimeObserverToken else { return }
        timeObservers.removeAll { $0.id == token.id }
    }

    internal func dispatchTimeUpdate(seconds: Double, duration: Double) {
        let time = CMTime(seconds: seconds)
        for observer in timeObservers {
            let block = observer.block
            let queue = observer.queue ?? .main
            nonisolated(unsafe) let unsafeBlock = block
            queue.async { unsafeBlock(time) }
        }
    }
}

/// Bridges Rust AudioPlayerDelegate callbacks to AVPlayer behavior.
private final class PlayerDelegateAdapter: AudioPlayerDelegate, @unchecked Sendable {
    private weak var player: AVPlayer?
    private let item: AVPlayerItem

    init(player: AVPlayer, item: AVPlayerItem) {
        self.player = player
        self.item = item
    }

    func onStateChanged(state: PlaybackState) {
        // State changes are reflected through rate and item status
    }

    func onTimeUpdate(currentSeconds: Double, durationSeconds: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.player?.dispatchTimeUpdate(seconds: currentSeconds, duration: durationSeconds)
        }
    }

    func onDidFinishPlaying() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.player?.rate = 0
            self.item.postDidPlayToEndTime()
        }
    }
}
