import Testing
import Foundation
@testable import AVFoundation

@Suite("AVPlayer")
struct AVPlayerTests {
    @Test func defaultInit() {
        let player = AVPlayer()
        #expect(player.rate == 0)
        #expect(player.currentItem == nil)
    }

    @Test func initWithURL() {
        let url = URL(fileURLWithPath: "/tmp/nonexistent-audio-file.mp3")
        let player = AVPlayer(url: url)
        #expect(player.currentItem != nil)
        #expect(player.rate == 0)
    }

    @Test func initWithPlayerItem() {
        let url = URL(fileURLWithPath: "/tmp/nonexistent-audio-file.mp3")
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        #expect(player.currentItem === item)
    }

    @Test func initWithNilPlayerItem() {
        let player = AVPlayer(playerItem: nil)
        #expect(player.currentItem == nil)
    }

    @Test func replaceCurrentItem() {
        let player = AVPlayer()
        #expect(player.currentItem == nil)

        let url = URL(fileURLWithPath: "/tmp/nonexistent-audio-file.mp3")
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        #expect(player.currentItem === item)

        player.replaceCurrentItem(with: nil)
        #expect(player.currentItem == nil)
    }

    @Test func addAndRemoveTimeObserver() {
        let player = AVPlayer()
        let interval = CMTime(seconds: 0.5)
        let token = player.addPeriodicTimeObserver(forInterval: interval, queue: nil) { _ in }
        #expect(token is TimeObserverToken)
        player.removeTimeObserver(token)
    }

    @Test func currentTimeDefaultsToZero() {
        let player = AVPlayer()
        #expect(player.currentTime == .zero)
    }
}
