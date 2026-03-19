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
        .zstack(children: [
            // Frosted glass background
            ViewNode.blur(radius: 20),
            ViewNode.roundedRect(
                width: screenWidth,
                height: Self.height,
                radius: 0,
                fill: DesktopColor(r: 0.1, g: 0.1, b: 0.1, a: 0.5)
            ),
            // Content
            ViewNode.hstack(alignment: .center, spacing: 16, children: [
                // Apple logo placeholder
                ViewNode.text("\u{F8FF}", fontSize: 14, color: .white),
                // App name (bold)
                ViewNode.text(appName, fontSize: 13, color: .white),
                // Menu items
                ViewNode.text("File", fontSize: 13, color: .text),
                ViewNode.text("Edit", fontSize: 13, color: .text),
                ViewNode.text("View", fontSize: 13, color: .text),
                ViewNode.text("Window", fontSize: 13, color: .text),
                ViewNode.text("Help", fontSize: 13, color: .text),
                // Spacer pushes clock right
                ViewNode.spacer(minLength: 0),
                // Clock
                ViewNode.text(clock, fontSize: 13, color: .white),
            ]),
        ])
    }
}
