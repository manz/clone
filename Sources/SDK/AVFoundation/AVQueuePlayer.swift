import Foundation
import AudioBridge

public class AVQueuePlayer: AVPlayer {
    private var queue: [AVPlayerItem] = []

    public override init() {
        super.init()
    }

    public init(items: [AVPlayerItem]) {
        super.init()
        queue = items
        if let first = queue.first {
            replaceCurrentItem(with: first)
        }
    }

    public func items() -> [AVPlayerItem] {
        queue
    }

    public func insert(_ item: AVPlayerItem, after afterItem: AVPlayerItem?) {
        if let afterItem, let index = queue.firstIndex(where: { $0 === afterItem }) {
            queue.insert(item, at: index + 1)
        } else {
            queue.append(item)
        }
        // If nothing is playing, start the first item
        if currentItem == nil, let first = queue.first {
            replaceCurrentItem(with: first)
        }
    }

    public func remove(_ item: AVPlayerItem) {
        queue.removeAll { $0 === item }
    }

    public func removeAllItems() {
        queue.removeAll()
        replaceCurrentItem(with: nil)
    }

    public func advanceToNextItem() {
        guard !queue.isEmpty else { return }
        // Remove the current (first) item
        queue.removeFirst()
        if let next = queue.first {
            replaceCurrentItem(with: next)
        } else {
            replaceCurrentItem(with: nil)
        }
    }

    public func canInsert(_ item: AVPlayerItem, after afterItem: AVPlayerItem?) -> Bool {
        true
    }
}
