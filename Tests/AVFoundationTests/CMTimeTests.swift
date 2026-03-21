import Testing
@testable import AVFoundation

@Suite("CMTime")
struct CMTimeTests {
    @Test func zeroTime() {
        let zero = CMTime.zero
        #expect(zero.seconds == 0)
        #expect(zero.value == 0)
        #expect(zero.timescale == 1)
    }

    @Test func initWithSeconds() {
        let time = CMTime(seconds: 2.5)
        #expect(time.seconds == 2.5)
        #expect(time.timescale == 600)
        #expect(time.value == 1500)
    }

    @Test func initWithCustomTimescale() {
        let time = CMTime(seconds: 1.0, preferredTimescale: 1000)
        #expect(time.seconds == 1.0)
        #expect(time.timescale == 1000)
        #expect(time.value == 1000)
    }

    @Test func cmTimeGetSeconds() {
        let time = CMTime(seconds: 3.14)
        let secs = CMTimeGetSeconds(time)
        #expect(abs(secs - 3.14) < 0.001)
    }

    @Test func cmTimeMake() {
        let time = CMTimeMake(value: 3000, timescale: 600)
        #expect(abs(time.seconds - 5.0) < 0.001)
    }

    @Test func equality() {
        let a = CMTime(seconds: 1.0, preferredTimescale: 600)
        let b = CMTime(seconds: 1.0, preferredTimescale: 600)
        #expect(a == b)
    }
}
