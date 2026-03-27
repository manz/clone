import SwiftUI

/// Produces window chrome render commands in local coordinates (0,0 = window top-left).
@MainActor
struct ChromeRenderer {
    static func renderWindow(
        width: Float, height: Float, radius: Float,
        isFocused: Bool, isMaximized: Bool,
        showTrafficLightSymbols: Bool, title: String
    ) -> [RenderCommand] {
        var commands: [RenderCommand] = []

        let tbColor: Color = isFocused ? WindowChrome.titleBar : WindowChrome.titleBarUnfocused
        let bgColor: Color = isFocused ? WindowChrome.surface : WindowChrome.background

        // 1. Window background
        commands.append(.roundedRect(
            x: 0, y: 0, w: width, h: height,
            radius: radius, color: bgColor.toEngine()
        ))

        // 2. Title bar + chrome drawn on top (clipped to title bar area only)
        let tbH = Float(WindowChrome.titleBarHeight)
        commands.append(.pushClip(x: 0, y: 0, w: width, h: tbH, radius: 0))
        commands.append(.rect(
            x: 0, y: 0, w: width, h: Float(WindowChrome.titleBarHeight),
            color: tbColor.toEngine()
        ))

        // Traffic lights
        let btnY = Float(WindowChrome.buttonInsetY)
        let btnX = Float(WindowChrome.buttonInsetX)
        let btnSize = Float(WindowChrome.buttonSize)
        let btnStep = btnSize + Float(WindowChrome.buttonSpacing)

        let closeColor: Color = isFocused ? .red : .gray
        let minColor: Color = isFocused ? .yellow : .gray
        let zoomColor: Color = isFocused ? .green : .gray

        commands.append(.roundedRect(x: btnX, y: btnY, w: btnSize, h: btnSize, radius: btnSize / 2, color: closeColor.toEngine()))
        commands.append(.roundedRect(x: btnX + btnStep, y: btnY, w: btnSize, h: btnSize, radius: btnSize / 2, color: minColor.toEngine()))
        commands.append(.roundedRect(x: btnX + btnStep * 2, y: btnY, w: btnSize, h: btnSize, radius: btnSize / 2, color: zoomColor.toEngine()))

        // Traffic light symbols on hover
        if showTrafficLightSymbols {
            let iconSize = btnSize * 0.6
            let symX = { (base: Float) in base + (btnSize - iconSize) / 2 }
            let symY = btnY + (btnSize - iconSize) / 2
            let symColor = RgbaColor(r: 0, g: 0, b: 0, a: 0.5)
            let zoomName = isMaximized ? "arrows-in" : "arrows-out"
            commands.append(.icon(name: "x", style: .bold, x: symX(btnX), y: symY, w: iconSize, h: iconSize, color: symColor))
            commands.append(.icon(name: "minus", style: .bold, x: symX(btnX + btnStep), y: symY, w: iconSize, h: iconSize, color: symColor))
            commands.append(.icon(name: zoomName, style: .bold, x: symX(btnX + btnStep * 2), y: symY, w: iconSize, h: iconSize, color: symColor))
        }

        // Title text
        let titleColor: Color = isFocused ? .primary : .secondary
        let titleX = width / 2 - Float(title.count) * 4
        let titleY = (Float(WindowChrome.titleBarHeight) - 13) / 2
        commands.append(.text(
            x: titleX, y: titleY, content: title, fontSize: 13,
            color: titleColor.toEngine(), weight: .regular, maxWidth: nil, family: nil
        ))
        commands.append(.popClip)

        return commands
    }
}
