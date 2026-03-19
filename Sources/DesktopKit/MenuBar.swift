import Foundation

/// macOS-style global menu bar with frosted glass background.
public struct MenuBar {
    let screenWidth: Float
    let appName: String
    let clock: String

    public static let height: Float = 24

    public init(screenWidth: Float, appName: String = "Finder", clock: String = "12:00") {
        self.screenWidth = screenWidth
        self.appName = appName
        self.clock = clock
    }

    public func body() -> ViewNode {
        ZStack {
            RoundedRectangle(cornerRadius: 0)
                .fill(DesktopColor(r: 0.1, g: 0.1, b: 0.1, a: 0.5))
                .frame(width: screenWidth, height: Self.height)
            HStack(spacing: 16) {
                Text("\u{F8FF}").fontSize(14).foregroundColor(.white)
                Text(appName).fontSize(13).bold().foregroundColor(.white)
                Text("File").fontSize(13)
                Text("Edit").fontSize(13)
                Text("View").fontSize(13)
                Text("Window").fontSize(13)
                Text("Help").fontSize(13)
                Spacer()
                Text(clock).fontSize(13).foregroundColor(.white)
            }
        }
        .frame(width: screenWidth, height: Self.height)
    }
}
