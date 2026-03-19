import Foundation

/// Root desktop component — background + dock.
public struct Desktop {
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let mouseX: CGFloat
    let mouseY: CGFloat

    public init(screenWidth: CGFloat, screenHeight: CGFloat, mouseX: CGFloat = 0, mouseY: CGFloat = 0) {
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self.mouseX = mouseX
        self.mouseY = mouseY
    }

    public func body() -> ViewNode {
        // Just the wallpaper — dock and menubar are rendered by the compositor on top of windows
        Rectangle()
            .fill(WindowChrome.base)
            .frame(width: screenWidth, height: screenHeight)
    }
}
