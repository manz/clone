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
                .fill(.menuBarBackground)
                .frame(width: screenWidth, height: Self.height)
            HStack(spacing: 16) {
                Text("\u{F8FF}").fontSize(14).foregroundColor(.text)
                Text(appName).fontSize(13).bold().foregroundColor(.text)
                Text("File").fontSize(13)
                Text("Edit").fontSize(13)
                Text("View").fontSize(13)
                Text("Window").fontSize(13)
                Text("Help").fontSize(13)
                Spacer()
                Text(clock).fontSize(13).foregroundColor(.text)
            }
        }
        .frame(width: screenWidth, height: Self.height)
    }
}
