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
        .zstack {
            // Desktop background
            ViewNode.rect(width: screenWidth, height: screenHeight, fill: .base)
            // Desktop label
            ViewNode.text("Clone Desktop", fontSize: 32, color: .text)
            // Dock at bottom
            ViewNode.vstack(spacing: 0) {
                ViewNode.spacer(minLength: 0)
                Dock(mouseX: mouseX, screenWidth: screenWidth, screenHeight: screenHeight).body()
            }
        }
    }
}
