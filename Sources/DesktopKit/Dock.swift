import Foundation

/// macOS-style Dock with icon magnification on hover.
public struct Dock {
    public static let baseIconSize: Float = 48
    public static let maxScale: Float = 2.0
    public static let influenceRadius: Float = 150
    public static let padding: Float = 8
    public static let dockHeight: Float = 64

    let mouseX: Float
    let mouseY: Float
    let screenWidth: Float
    let screenHeight: Float

    public struct DockItem: Equatable {
        public let name: String
        public let color: DesktopColor

        public init(name: String, color: DesktopColor) {
            self.name = name
            self.color = color
        }
    }

    public static let defaultItems: [DockItem] = [
        DockItem(name: "Finder", color: .systemBlue),
        DockItem(name: "Safari", color: .systemBlue),
        DockItem(name: "Mail", color: .systemBlue),
        DockItem(name: "Music", color: .systemRed),
        DockItem(name: "Photos", color: .systemGreen),
        DockItem(name: "Terminal", color: .black),
        DockItem(name: "Settings", color: .muted),
    ]

    public init(mouseX: Float, mouseY: Float, screenWidth: Float, screenHeight: Float) {
        self.mouseX = mouseX
        self.mouseY = mouseY
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
    }

    public func body() -> ViewNode {
        let items = Self.defaultItems
        let iconSizes = Self.magnifiedSizes(
            mouseX: mouseX, mouseY: mouseY,
            items: items, screenWidth: screenWidth, screenHeight: screenHeight
        )

        let iconNodes: [ViewNode] = items.enumerated().map { (i, item) in
            let size = iconSizes[i]
            return RoundedRectangle(cornerRadius: size * 0.22)
                .fill(item.color)
                .frame(width: size, height: size)
        }

        let totalWidth = iconSizes.reduce(0, +) + Float(items.count - 1) * Self.padding + Self.padding * 2
        let dockBgHeight = Self.dockHeight + Self.padding * 2

        return .zstack(children: [
            RoundedRectangle(cornerRadius: 16)
                .fill(DesktopColor(r: 0.2, g: 0.2, b: 0.2, a: 0.6))
                .frame(width: totalWidth, height: dockBgHeight),
            ViewNode.hstack(alignment: .bottom, spacing: Self.padding, children: iconNodes),
        ])
    }

    /// The dock's bounding rect (centered at bottom of screen).
    public static func dockRect(items: [DockItem], screenWidth: Float, screenHeight: Float) -> (x: Float, y: Float, w: Float, h: Float) {
        let totalBaseWidth = Float(items.count) * baseIconSize + Float(items.count - 1) * padding + padding * 2
        let dockBgHeight = dockHeight + padding * 2
        let x = (screenWidth - totalBaseWidth) / 2
        let y = screenHeight - dockBgHeight
        return (x, y, totalBaseWidth, dockBgHeight)
    }

    /// Calculate magnified sizes for each icon based on mouse proximity.
    /// Only magnifies when the mouse is within or near the dock rect.
    public static func magnifiedSizes(
        mouseX: Float,
        mouseY: Float,
        items: [DockItem],
        screenWidth: Float,
        screenHeight: Float
    ) -> [Float] {
        let rect = dockRect(items: items, screenWidth: screenWidth, screenHeight: screenHeight)

        // Expand the hit zone by influenceRadius for the approach effect
        let hitLeft = rect.x - influenceRadius
        let hitRight = rect.x + rect.w + influenceRadius
        let hitTop = rect.y - influenceRadius
        let hitBottom = screenHeight

        let insideHitZone = mouseX >= hitLeft && mouseX <= hitRight
            && mouseY >= hitTop && mouseY <= hitBottom

        if !insideHitZone {
            return [Float](repeating: baseIconSize, count: items.count)
        }

        let totalBaseWidth = Float(items.count) * baseIconSize + Float(items.count - 1) * padding
        let startX: Float = (screenWidth - totalBaseWidth) / 2

        return items.enumerated().map { (i, _) in
            let iconCenterX: Float = startX + Float(i) * (baseIconSize + padding) + baseIconSize / 2
            let distance: Float = abs(mouseX - iconCenterX)
            if distance > influenceRadius {
                return baseIconSize
            }
            let t: Float = 1.0 - (distance / influenceRadius)
            let scale: Float = 1.0 + (maxScale - 1.0) * (1.0 - cosf(t * .pi)) / 2.0
            return baseIconSize * scale
        }
    }
}
