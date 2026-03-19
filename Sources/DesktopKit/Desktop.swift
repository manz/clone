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
        ZStack {
            Rectangle()
                .fill(.base)
                .frame(width: screenWidth, height: screenHeight)
            VStack(spacing: 0) {
                Spacer()
                Dock(mouseX: mouseX, mouseY: mouseY, screenWidth: screenWidth, screenHeight: screenHeight).body()
            }
        }
    }
}
