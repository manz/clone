import Foundation

/// A managed window on the desktop.
public struct ManagedWindow: Equatable, Sendable {
    public let id: UInt64
    public let appId: String
    public var title: String
    public var x: Float
    public var y: Float
    public var width: Float
    public var height: Float
    public var isVisible: Bool
    public var isMinimized: Bool
    public var isMaximized: Bool

    // Stored pre-maximize geometry for restore
    public var restoreX: Float
    public var restoreY: Float
    public var restoreWidth: Float
    public var restoreHeight: Float

    public init(id: UInt64, appId: String, title: String, x: Float, y: Float, width: Float, height: Float) {
        self.id = id
        self.appId = appId
        self.title = title
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.isVisible = true
        self.isMinimized = false
        self.isMaximized = false
        self.restoreX = x
        self.restoreY = y
        self.restoreWidth = width
        self.restoreHeight = height
    }

    public var frame: LayoutFrame {
        LayoutFrame(x: x, y: y, width: width, height: height)
    }

    public var titleBarFrame: LayoutFrame {
        LayoutFrame(x: x, y: y, width: width, height: WindowChrome.titleBarHeight)
    }

    public func contains(px: Float, py: Float) -> Bool {
        px >= x && px <= x + width && py >= y && py <= y + height
    }

    public func titleBarContains(px: Float, py: Float) -> Bool {
        px >= x && px <= x + width && py >= y && py <= y + WindowChrome.titleBarHeight
    }
}

/// Window chrome constants.
public enum WindowChrome {
    public static let titleBarHeight: Float = 38
    public static let buttonSize: Float = 12
    public static let buttonSpacing: Float = 8
    public static let buttonInsetX: Float = 14
    public static let buttonInsetY: Float = 13
    public static let cornerRadius: Float = 12
    public static let menuBarHeight: Float = 24
}

/// Which traffic light button was hit.
public enum TrafficLightButton {
    case close
    case minimize
    case zoom
}

/// Manages all windows: z-ordering, focus, movement, lifecycle.
public final class WindowManager {
    public var windows: [ManagedWindow] = []
    public private(set) var focusedWindowId: UInt64? = nil
    private var nextWindowId: UInt64 = 1

    /// Screen dimensions — set by the compositor each frame.
    public var screenWidth: Float = 1280
    public var screenHeight: Float = 800

    // Drag state
    private var dragWindowId: UInt64? = nil
    private var dragOffsetX: Float = 0
    private var dragOffsetY: Float = 0

    // Hover state for traffic lights
    public var hoveredWindowId: UInt64? = nil
    public var hoveringTrafficLights: Bool = false

    public init() {}

    // MARK: - Lifecycle

    @discardableResult
    public func open(appId: String, title: String, x: Float, y: Float, width: Float, height: Float) -> UInt64 {
        let id = nextWindowId
        nextWindowId += 1
        let window = ManagedWindow(id: id, appId: appId, title: title, x: x, y: y, width: width, height: height)
        windows.append(window)
        focusedWindowId = id
        return id
    }

    public func close(id: UInt64) {
        windows.removeAll { $0.id == id }
        if focusedWindowId == id {
            focusedWindowId = windows.last(where: { !$0.isMinimized })?.id
        }
    }

    /// Minimize — hide from desktop, keep in window list (like macOS miniaturize).
    public func minimize(id: UInt64) {
        guard let idx = windows.firstIndex(where: { $0.id == id }) else { return }
        windows[idx].isMinimized = true
        windows[idx].isVisible = false
        if focusedWindowId == id {
            focusedWindowId = windows.last(where: { !$0.isMinimized && $0.isVisible })?.id
        }
    }

    /// Unminimize — restore from dock.
    public func unminimize(id: UInt64) {
        guard let idx = windows.firstIndex(where: { $0.id == id }) else { return }
        windows[idx].isMinimized = false
        windows[idx].isVisible = true
        focus(id: id)
    }

    /// Zoom — toggle between maximized and restored (like macOS green button).
    /// Maximized fills the screen below the menu bar.
    public func zoom(id: UInt64) {
        guard let idx = windows.firstIndex(where: { $0.id == id }) else { return }

        if windows[idx].isMaximized {
            // Restore to previous size/position
            windows[idx].x = windows[idx].restoreX
            windows[idx].y = windows[idx].restoreY
            windows[idx].width = windows[idx].restoreWidth
            windows[idx].height = windows[idx].restoreHeight
            windows[idx].isMaximized = false
        } else {
            // Save current geometry, then maximize
            windows[idx].restoreX = windows[idx].x
            windows[idx].restoreY = windows[idx].y
            windows[idx].restoreWidth = windows[idx].width
            windows[idx].restoreHeight = windows[idx].height

            windows[idx].x = 0
            windows[idx].y = WindowChrome.menuBarHeight
            windows[idx].width = screenWidth
            windows[idx].height = screenHeight - WindowChrome.menuBarHeight
            windows[idx].isMaximized = true
        }
    }

    public func focus(id: UInt64) {
        guard let idx = windows.firstIndex(where: { $0.id == id }) else { return }
        let window = windows.remove(at: idx)
        windows.append(window)
        focusedWindowId = id
    }

    // MARK: - Hit testing

    public func windowAt(x: Float, y: Float) -> ManagedWindow? {
        for window in windows.reversed() {
            if window.isVisible && !window.isMinimized && window.contains(px: x, py: y) {
                return window
            }
        }
        return nil
    }

    /// Hit-test traffic light buttons. Returns which button was hit, or nil.
    public func hitTestTrafficLight(windowId: UInt64, x: Float, y: Float) -> TrafficLightButton? {
        guard let window = windows.first(where: { $0.id == windowId }) else { return nil }

        let btnY = window.y + WindowChrome.buttonInsetY
        let btnCenterY = btnY + WindowChrome.buttonSize / 2
        let dy = y - btnCenterY
        // Must be vertically within the buttons
        guard abs(dy) <= WindowChrome.buttonSize else { return nil }

        let closeX = window.x + WindowChrome.buttonInsetX + WindowChrome.buttonSize / 2
        let minimizeX = closeX + WindowChrome.buttonSize + WindowChrome.buttonSpacing
        let zoomX = minimizeX + WindowChrome.buttonSize + WindowChrome.buttonSpacing

        let hitRadius = WindowChrome.buttonSize // generous
        if abs(x - closeX) <= hitRadius { return .close }
        if abs(x - minimizeX) <= hitRadius { return .minimize }
        if abs(x - zoomX) <= hitRadius { return .zoom }

        return nil
    }

    /// Check if mouse is hovering over the traffic light area of a window.
    public func isOverTrafficLights(windowId: UInt64, x: Float, y: Float) -> Bool {
        guard let window = windows.first(where: { $0.id == windowId }) else { return false }
        let btnY = window.y + WindowChrome.buttonInsetY
        let btnEndX = window.x + WindowChrome.buttonInsetX + WindowChrome.buttonSize * 3 + WindowChrome.buttonSpacing * 2 + 8
        return x >= window.x && x <= btnEndX
            && y >= btnY - 4 && y <= btnY + WindowChrome.buttonSize + 4
    }

    // Keep the old method for backwards compat
    public func hitsCloseButton(windowId: UInt64, x: Float, y: Float) -> Bool {
        hitTestTrafficLight(windowId: windowId, x: x, y: y) == .close
    }

    // MARK: - Dragging

    public func beginDrag(windowId: UInt64, mouseX: Float, mouseY: Float) {
        guard let window = windows.first(where: { $0.id == windowId }) else { return }
        // If maximized, drag should unmaximize and reposition (like macOS)
        if window.isMaximized {
            if let idx = windows.firstIndex(where: { $0.id == windowId }) {
                let restoreW = windows[idx].restoreWidth
                windows[idx].isMaximized = false
                windows[idx].width = windows[idx].restoreWidth
                windows[idx].height = windows[idx].restoreHeight
                // Center the restored window under the cursor
                windows[idx].x = mouseX - restoreW / 2
                windows[idx].y = mouseY - WindowChrome.titleBarHeight / 2
            }
        }
        dragWindowId = windowId
        let w = windows.first(where: { $0.id == windowId })!
        dragOffsetX = mouseX - w.x
        dragOffsetY = mouseY - w.y
        focus(id: windowId)
    }

    public func updateDrag(mouseX: Float, mouseY: Float) {
        guard let id = dragWindowId,
              let idx = windows.firstIndex(where: { $0.id == id }) else { return }
        windows[idx].x = mouseX - dragOffsetX
        // Prevent dragging above the menubar
        windows[idx].y = max(mouseY - dragOffsetY, WindowChrome.menuBarHeight)
    }

    public func endDrag() {
        dragWindowId = nil
    }

    public var isDragging: Bool { dragWindowId != nil }

    /// Minimized windows (for dock display).
    public var minimizedWindows: [ManagedWindow] {
        windows.filter(\.isMinimized)
    }

    // MARK: - Rendering

    /// Render a single window's chrome (no app content — content is overlaid by the compositor).
    public func renderSingle(window: ManagedWindow, isFocused: Bool, showTrafficLightSymbols: Bool) -> ViewNode {
        windowChrome(window: window, isFocused: isFocused,
                    showTrafficLightSymbols: showTrafficLightSymbols,
                    content: ViewNode.empty)
    }

    public func render(contentProvider: (ManagedWindow) -> ViewNode) -> [ViewNode] {
        windows.filter({ $0.isVisible && !$0.isMinimized }).map { window in
            let content = contentProvider(window)
            let isFocused = window.id == focusedWindowId
            let showTrafficLightSymbols = hoveredWindowId == window.id && hoveringTrafficLights
            return windowChrome(window: window, isFocused: isFocused,
                              showTrafficLightSymbols: showTrafficLightSymbols, content: content)
        }
    }

    private func windowChrome(window: ManagedWindow, isFocused: Bool,
                              showTrafficLightSymbols: Bool, content: ViewNode) -> ViewNode {
        let radius = window.isMaximized ? Float(0) : WindowChrome.cornerRadius

        let windowBody = ZStack {
            // Window background
            RoundedRectangle(cornerRadius: radius)
                .fill(isFocused ? .surface : DesktopColor(r: 0.16, g: 0.15, b: 0.21))
                .frame(width: window.width, height: window.height)
            // Content area
            VStack(alignment: .leading, spacing: 0) {
                titleBar(window: window, isFocused: isFocused,
                        showSymbols: showTrafficLightSymbols)
                content.frame(width: window.width)
            }
            .frame(width: window.width, height: window.height)
        }

        // Apply shadow (GPU-rendered SDF blur) unless maximized
        let withShadow: ViewNode
        if window.isMaximized {
            withShadow = windowBody
        } else {
            withShadow = windowBody
                .shadow(
                    color: DesktopColor(r: 0, g: 0, b: 0, a: isFocused ? 0.18 : 0.08),
                    radius: isFocused ? 24 : 12,
                    x: 0,
                    y: isFocused ? 10 : 5
                )
        }

        return ViewNode.padding(
            EdgeInsets(top: window.y, leading: window.x, bottom: 0, trailing: 0),
            child: withShadow
        )
    }

    private func titleBar(window: ManagedWindow, isFocused: Bool, showSymbols: Bool) -> ViewNode {
        let tbRadius: Float = window.isMaximized ? 0 : 0
        return ZStack {
            RoundedRectangle(cornerRadius: tbRadius)
                .fill(isFocused ? .overlay : DesktopColor(r: 0.19, g: 0.17, b: 0.24))
                .frame(width: window.width, height: WindowChrome.titleBarHeight)
            HStack(spacing: WindowChrome.buttonSpacing) {
                // Traffic lights — colored when focused, gray when not
                trafficLightButton(
                    color: isFocused ? .systemRed : .muted,
                    symbol: showSymbols ? "×" : nil
                )
                trafficLightButton(
                    color: isFocused ? .systemYellow : .muted,
                    symbol: showSymbols ? "−" : nil
                )
                trafficLightButton(
                    color: isFocused ? .systemGreen : .muted,
                    symbol: showSymbols ? (window.isMaximized ? "↙" : "↗") : nil
                )
                Spacer()
                Text(window.title).fontSize(13).foregroundColor(isFocused ? .text : .subtle)
                Spacer()
            }
        }
        .frame(width: window.width, height: WindowChrome.titleBarHeight)
    }

    private func trafficLightButton(color: DesktopColor, symbol: String?) -> ViewNode {
        let size = WindowChrome.buttonSize
        if let symbol {
            return ZStack {
                RoundedRectangle(cornerRadius: size / 2)
                    .fill(color)
                    .frame(width: size, height: size)
                Text(symbol)
                    .fontSize(size * 0.7)
                    .bold()
                    .foregroundColor(DesktopColor(r: 0, g: 0, b: 0, a: 0.5))
            }
            .frame(width: size, height: size)
        } else {
            return RoundedRectangle(cornerRadius: size / 2)
                .fill(color)
                .frame(width: size, height: size)
        }
    }
}
