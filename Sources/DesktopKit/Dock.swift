import Foundation

/// macOS-style Dock with icon magnification on hover.
public struct Dock {
    public static let baseIconSize: Float = 48
    public static let maxScale: Float = 2.0
    public static let influenceRadius: Float = 150
    public static let padding: Float = 8
    public static let dockHeight: Float = 64

    let mouseX: Float
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

    public init(mouseX: Float, screenWidth: Float, screenHeight: Float) {
        self.mouseX = mouseX
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
    }

    public func body() -> ViewNode {
        let items = Self.defaultItems
        let iconSizes = Self.magnifiedSizes(mouseX: mouseX, items: items, screenWidth: screenWidth)

        // Build icon nodes
        let iconNodes: [ViewNode] = items.enumerated().map { (i, item) in
            let size = iconSizes[i]
            return ViewNode.roundedRect(width: size, height: size, radius: size * 0.22, fill: item.color)
        }

        // Dock background
        let totalWidth = iconSizes.reduce(0, +) + Float(items.count - 1) * Self.padding + Self.padding * 2
        let dockBgHeight = Self.dockHeight + Self.padding * 2

        return .zstack(children: [
            ViewNode.roundedRect(
                width: totalWidth,
                height: dockBgHeight,
                radius: 16,
                fill: DesktopColor(r: 0.2, g: 0.2, b: 0.2, a: 0.6)
            ),
            ViewNode.hstack(alignment: .bottom, spacing: Self.padding, children: iconNodes),
        ])
    }

    /// Calculate magnified sizes for each icon based on mouse proximity.
    public static func magnifiedSizes(
        mouseX: Float,
        items: [DockItem],
        screenWidth: Float
    ) -> [Float] {
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
