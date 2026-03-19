import Foundation

/// Root desktop component — background + dock.
public struct Desktop {
    let screenWidth: Float
    let screenHeight: Float
    let mouseX: Float
    let mouseY: Float

    public init(screenWidth: Float, screenHeight: Float, mouseX: Float = 0, mouseY: Float = 0) {
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
