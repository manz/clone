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
        public let appId: String
        public let name: String
        public let color: Color

        public init(appId: String, name: String, color: Color) {
            self.appId = appId
            self.name = name
            self.color = color
        }
    }

    public static let defaultItems: [DockItem] = [
        DockItem(appId: "com.clone.finder", name: "Finder", color: .systemBlue),
        DockItem(appId: "com.clone.safari", name: "Safari", color: .systemBlue),
        DockItem(appId: "com.clone.mail", name: "Mail", color: .systemBlue),
        DockItem(appId: "com.clone.music", name: "Music", color: .systemRed),
        DockItem(appId: "com.clone.photos", name: "Photos", color: .systemGreen),
        DockItem(appId: "com.clone.terminal", name: "Terminal", color: .black),
        DockItem(appId: "com.clone.settings", name: "Settings", color: .muted),
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
        let hoveredIndex = Self.hoveredIconIndex(
            mouseX: mouseX, mouseY: mouseY,
            items: items, screenWidth: screenWidth, screenHeight: screenHeight
        )

        // Build icon nodes with tap handlers and popover
        let iconNodes: [ViewNode] = items.enumerated().map { (i, item) in
            let size = iconSizes[i]
            let icon = RoundedRectangle(cornerRadius: size * 0.22)
                .fill(item.color)
                .frame(width: size, height: size)
                .onTapGesture {
                    DockActionRegistry.shared.lastTappedAppId = item.appId
                }

            if i == hoveredIndex {
                // Show popover label above hovered icon
                return VStack(spacing: 4) {
                    popoverLabel(item.name)
                    icon
                }
            } else {
                return icon
            }
        }

        let totalWidth = iconSizes.reduce(0, +) + Float(items.count - 1) * Self.padding + Self.padding * 2
        let dockBgHeight = Self.dockHeight + Self.padding * 2

        return .zstack(children: [
            RoundedRectangle(cornerRadius: 16)
                .fill(.dockBackground)
                .frame(width: totalWidth, height: dockBgHeight),
            ViewNode.hstack(alignment: .bottom, spacing: Self.padding, children: iconNodes),
        ])
    }

    private func popoverLabel(_ name: String) -> ViewNode {
        let textWidth = Float(name.count) * 8 + 20
        let height: Float = 26
        return ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(.popoverBackground)
                .frame(width: textWidth, height: height)
            Text(name)
                .fontSize(12)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(width: textWidth, height: height)
        }
        .frame(width: textWidth, height: height)
    }

    // MARK: - Hit testing

    /// Which icon index is the mouse hovering over (nil if none).
    public static func hoveredIconIndex(
        mouseX: Float, mouseY: Float,
        items: [DockItem], screenWidth: Float, screenHeight: Float
    ) -> Int? {
        let rect = dockRect(items: items, screenWidth: screenWidth, screenHeight: screenHeight)

        // Must be within dock vertical zone
        guard mouseY >= rect.y && mouseY <= screenHeight else { return nil }

        let totalBaseWidth = Float(items.count) * baseIconSize + Float(items.count - 1) * padding
        let startX: Float = (screenWidth - totalBaseWidth) / 2

        for i in 0..<items.count {
            let iconLeft = startX + Float(i) * (baseIconSize + padding)
            let iconRight = iconLeft + baseIconSize
            if mouseX >= iconLeft && mouseX <= iconRight {
                return i
            }
        }
        return nil
    }

    /// Get the screen-space rect for a specific dock icon slot (for animation targets).
    public static func iconRect(index: Int, screenWidth: Float, screenHeight: Float) -> AnimRect {
        let items = defaultItems
        let totalBaseWidth = Float(items.count) * baseIconSize + Float(items.count - 1) * padding
        let startX = (screenWidth - totalBaseWidth) / 2
        let dockY = screenHeight - dockHeight - padding * 2
        let iconX = startX + Float(index) * (baseIconSize + padding)
        let iconY = dockY + padding + (dockHeight - baseIconSize) / 2
        return AnimRect(x: iconX, y: iconY, w: baseIconSize, h: baseIconSize)
    }

    /// Find the dock icon index for a given appId.
    public static func iconIndex(for appId: String) -> Int? {
        defaultItems.firstIndex(where: { $0.appId == appId })
    }

    public static func dockRect(items: [DockItem], screenWidth: Float, screenHeight: Float) -> (x: Float, y: Float, w: Float, h: Float) {
        let totalBaseWidth = Float(items.count) * baseIconSize + Float(items.count - 1) * padding + padding * 2
        let dockBgHeight = dockHeight + padding * 2
        let x = (screenWidth - totalBaseWidth) / 2
        let y = screenHeight - dockBgHeight
        return (x, y, totalBaseWidth, dockBgHeight)
    }

    public static func magnifiedSizes(
        mouseX: Float, mouseY: Float,
        items: [DockItem], screenWidth: Float, screenHeight: Float
    ) -> [Float] {
        let rect = dockRect(items: items, screenWidth: screenWidth, screenHeight: screenHeight)

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

/// Shared registry to communicate dock icon taps back to the compositor.
/// The compositor checks this each frame and launches the requested app.
public final class DockActionRegistry {
    public static let shared = DockActionRegistry()
    public var lastTappedAppId: String? = nil
    private init() {}

    public func consume() -> String? {
        let id = lastTappedAppId
        lastTappedAppId = nil
        return id
    }
}
