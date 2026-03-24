// Aquax SDK stub: UniformTypeIdentifiers
// UTType stubs for compilation.
import Foundation

public struct UTType: Hashable, Sendable {
    public let identifier: String
    public init(_ identifier: String) { self.identifier = identifier }

    public static let audio = UTType("public.audio")
    public static let mpeg4Audio = UTType("public.mpeg-4-audio")
    public static let mp3 = UTType("public.mp3")
    public static let data = UTType("public.data")
    public static let fileURL = UTType("public.file-url")
    public static let png = UTType("public.png")
    public static let jpeg = UTType("public.jpeg")
    public static let url = UTType("public.url")
    public static let text = UTType("public.plain-text")
    public static let item = UTType("public.item")
    public static let image = UTType("public.image")
    public static let movie = UTType("public.movie")
    public static let video = UTType("public.video")
    public static let livePhoto = UTType("com.apple.live-photo")
    public static let json = UTType("public.json")
    public static let pdf = UTType("com.adobe.pdf")

    public var preferredFilenameExtension: String? { nil }
    public init?(filenameExtension: String) { self.identifier = "public.\(filenameExtension)" }
}
