import Foundation

public struct CMTime: Equatable, Sendable {
    public var value: Int64
    public var timescale: Int32

    public var seconds: Double {
        timescale == 0 ? 0 : Double(value) / Double(timescale)
    }

    public var isValid: Bool { timescale > 0 }

    public static let zero = CMTime(value: 0, timescale: 1)

    public init(seconds: Double, preferredTimescale: Int32 = 600) {
        self.value = Int64(seconds * Double(preferredTimescale))
        self.timescale = preferredTimescale
    }

    public init(value: Int64, timescale: Int32) {
        self.value = value
        self.timescale = timescale
    }
}

public func CMTimeGetSeconds(_ time: CMTime) -> Double { time.seconds }
public func CMTimeMake(value: Int64, timescale: Int32) -> CMTime {
    CMTime(value: value, timescale: timescale)
}
