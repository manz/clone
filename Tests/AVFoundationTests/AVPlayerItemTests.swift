import Testing
import Foundation
@testable import AVFoundation

@Suite("AVPlayerItem")
struct AVPlayerItemTests {
    @Test func initWithNonexistentURL() {
        let url = URL(fileURLWithPath: "/tmp/nonexistent-audio-file.mp3")
        let item = AVPlayerItem(url: url)
        // File doesn't exist so probe fails
        #expect(item.status == .failed)
    }

    @Test func initWithAsset() {
        let url = URL(fileURLWithPath: "/tmp/nonexistent-audio-file.mp3")
        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        #expect(item.asset === asset)
    }

    @Test func didPlayToEndTimeNotificationName() {
        let name = AVPlayerItem.didPlayToEndTimeNotification
        #expect(name.rawValue == "AVPlayerItemDidPlayToEndTime")
    }
}
