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
                .fill(WindowChrome.menuBar)
                .frame(width: screenWidth, height: Self.height)
            HStack(spacing: 16) {
                Text("\u{F8FF}").font(.system(size: 14)).foregroundColor(.primary)
                Text(appName).font(.system(size: 13, weight: .bold)).foregroundColor(.primary)
                Text("File").font(.system(size: 13))
                Text("Edit").font(.system(size: 13))
                Text("View").font(.system(size: 13))
                Text("Window").font(.system(size: 13))
                Text("Help").font(.system(size: 13))
                Spacer()
                Text(clock).font(.system(size: 13)).foregroundColor(.primary)
            }
        }
        .frame(width: screenWidth, height: Self.height)
    }
}
