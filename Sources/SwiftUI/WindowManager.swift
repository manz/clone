import Foundation

/// A managed window on the desktop.
public struct ManagedWindow: Equatable, Sendable {
    public let id: UInt64
    public let appId: String
    public var title: String
    public var x: CGFloat
    public var y: CGFloat
    public var width: CGFloat
    public var height: CGFloat
    public var isVisible: Bool
    public var isMinimized: Bool
    public var isMaximized: Bool

    // Stored pre-maximize geometry for restore
    public var restoreX: CGFloat
    public var restoreY: CGFloat
    public var restoreWidth: CGFloat
    public var restoreHeight: CGFloat

    public init(id: UInt64, appId: String, title: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
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

    public func contains(px: CGFloat, py: CGFloat) -> Bool {
        px >= x && px <= x + width && py >= y && py <= y + height
    }

    public func titleBarContains(px: CGFloat, py: CGFloat) -> Bool {
        px >= x && px <= x + width && py >= y && py <= y + WindowChrome.titleBarHeight
    }
}

/// Window chrome constants.
public enum WindowChrome {
    public static let titleBarHeight: CGFloat = 38
    public static let buttonSize: CGFloat = 12
    public static let buttonSpacing: CGFloat = 8
    public static let buttonInsetX: CGFloat = 14
    public static let buttonInsetY: CGFloat = 13
    public static let cornerRadius: CGFloat = 12
    public static let menuBarHeight: CGFloat = 24
    public static let resizeHandleSize: CGFloat = 6
    public static let minWindowWidth: CGFloat = 200
    public static let minWindowHeight: CGFloat = 150
}

/// Which edge/corner is being resized.
public enum ResizeEdge: Equatable {
    case topLeft, top, topRight
    case left, right
    case bottomLeft, bottom, bottomRight
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
    public var screenWidth: CGFloat = 1280
    public var screenHeight: CGFloat = 800

    // Drag state
    private var dragWindowId: UInt64? = nil
    private var dragOffsetX: CGFloat = 0
    private var dragOffsetY: CGFloat = 0

    // Hover state for traffic lights
    public var hoveredWindowId: UInt64? = nil
    public var hoveringTrafficLights: Bool = false

    // Resize state
    private var resizeWindowId: UInt64? = nil
    private var resizeEdge: ResizeEdge? = nil
    private var resizeStartMouseX: CGFloat = 0
    private var resizeStartMouseY: CGFloat = 0
    private var resizeStartX: CGFloat = 0
    private var resizeStartY: CGFloat = 0
    private var resizeStartW: CGFloat = 0
    private var resizeStartH: CGFloat = 0

    public init() {}

    // MARK: - Lifecycle

    @discardableResult
    public func open(appId: String, title: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> UInt64 {
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

    public func windowAt(x: CGFloat, y: CGFloat) -> ManagedWindow? {
        for window in windows.reversed() {
            if window.isVisible && !window.isMinimized && window.contains(px: x, py: y) {
                return window
            }
        }
        return nil
    }

    /// Hit-test traffic light buttons. Returns which button was hit, or nil.
    public func hitTestTrafficLight(windowId: UInt64, x: CGFloat, y: CGFloat) -> TrafficLightButton? {
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
    public func isOverTrafficLights(windowId: UInt64, x: CGFloat, y: CGFloat) -> Bool {
        guard let window = windows.first(where: { $0.id == windowId }) else { return false }
        let btnY = window.y + WindowChrome.buttonInsetY
        let btnEndX = window.x + WindowChrome.buttonInsetX + WindowChrome.buttonSize * 3 + WindowChrome.buttonSpacing * 2 + 8
        return x >= window.x && x <= btnEndX
            && y >= btnY - 4 && y <= btnY + WindowChrome.buttonSize + 4
    }

    // Keep the old method for backwards compat
    public func hitsCloseButton(windowId: UInt64, x: CGFloat, y: CGFloat) -> Bool {
        hitTestTrafficLight(windowId: windowId, x: x, y: y) == .close
    }

    // MARK: - Dragging

    public func beginDrag(windowId: UInt64, mouseX: CGFloat, mouseY: CGFloat) {
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

    public func updateDrag(mouseX: CGFloat, mouseY: CGFloat) {
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

    // MARK: - Resizing

    /// Hit-test the edges/corners of a window. Returns the resize edge or nil.
    public func hitTestResizeEdge(windowId: UInt64, x: CGFloat, y: CGFloat) -> ResizeEdge? {
        guard let window = windows.first(where: { $0.id == windowId }) else { return nil }
        guard !window.isMaximized else { return nil }

        let r = WindowChrome.resizeHandleSize
        let left = x >= window.x - r && x <= window.x + r
        let right = x >= window.x + window.width - r && x <= window.x + window.width + r
        let top = y >= window.y - r && y <= window.y + r
        let bottom = y >= window.y + window.height - r && y <= window.y + window.height + r
        let inX = x >= window.x - r && x <= window.x + window.width + r
        let inY = y >= window.y - r && y <= window.y + window.height + r

        if top && left { return .topLeft }
        if top && right { return .topRight }
        if bottom && left { return .bottomLeft }
        if bottom && right { return .bottomRight }
        if top && inX { return .top }
        if bottom && inX { return .bottom }
        if left && inY { return .left }
        if right && inY { return .right }
        return nil
    }

    /// Begin resizing a window from the given edge.
    public func beginResize(windowId: UInt64, edge: ResizeEdge, mouseX: CGFloat, mouseY: CGFloat) {
        guard let window = windows.first(where: { $0.id == windowId }) else { return }
        resizeWindowId = windowId
        resizeEdge = edge
        resizeStartMouseX = mouseX
        resizeStartMouseY = mouseY
        resizeStartX = window.x
        resizeStartY = window.y
        resizeStartW = window.width
        resizeStartH = window.height
        focus(id: windowId)
    }

    /// Update the resize drag.
    public func updateResize(mouseX: CGFloat, mouseY: CGFloat) {
        guard let id = resizeWindowId, let edge = resizeEdge,
              let idx = windows.firstIndex(where: { $0.id == id }) else { return }

        let dx = mouseX - resizeStartMouseX
        let dy = mouseY - resizeStartMouseY
        let minW = WindowChrome.minWindowWidth
        let minH = WindowChrome.minWindowHeight

        switch edge {
        case .bottomRight:
            windows[idx].width = max(resizeStartW + dx, minW)
            windows[idx].height = max(resizeStartH + dy, minH)
        case .bottomLeft:
            let newW = max(resizeStartW - dx, minW)
            windows[idx].x = resizeStartX + resizeStartW - newW
            windows[idx].width = newW
            windows[idx].height = max(resizeStartH + dy, minH)
        case .topRight:
            windows[idx].width = max(resizeStartW + dx, minW)
            let newH = max(resizeStartH - dy, minH)
            windows[idx].y = max(resizeStartY + resizeStartH - newH, WindowChrome.menuBarHeight)
            windows[idx].height = newH
        case .topLeft:
            let newW = max(resizeStartW - dx, minW)
            windows[idx].x = resizeStartX + resizeStartW - newW
            windows[idx].width = newW
            let newH = max(resizeStartH - dy, minH)
            windows[idx].y = max(resizeStartY + resizeStartH - newH, WindowChrome.menuBarHeight)
            windows[idx].height = newH
        case .right:
            windows[idx].width = max(resizeStartW + dx, minW)
        case .left:
            let newW = max(resizeStartW - dx, minW)
            windows[idx].x = resizeStartX + resizeStartW - newW
            windows[idx].width = newW
        case .bottom:
            windows[idx].height = max(resizeStartH + dy, minH)
        case .top:
            let newH = max(resizeStartH - dy, minH)
            windows[idx].y = max(resizeStartY + resizeStartH - newH, WindowChrome.menuBarHeight)
            windows[idx].height = newH
        }
    }

    /// End resizing.
    public func endResize() {
        resizeWindowId = nil
        resizeEdge = nil
    }

    public var isResizing: Bool { resizeWindowId != nil }

    /// The window ID currently being resized (for resize notification).
    public var resizingWindowId: UInt64? { resizeWindowId }

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
        let radius: CGFloat = window.isMaximized ? 0 : WindowChrome.cornerRadius

        let windowBody = ZStack {
            // Window background
            RoundedRectangle(cornerRadius: radius)
                .fill(isFocused ? WindowChrome.surface : WindowChrome.backgroundUnfocused)
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
                    color: .black.withAlpha(isFocused ? 0.18 : 0.08),
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
        let w = window.width
        let h = WindowChrome.titleBarHeight
        let bg = isFocused ? WindowChrome.titleBar : WindowChrome.titleBarUnfocused

        // Build the HStack content as a flat array — no spacers, manual positioning
        // This avoids layout issues with nested ZStack/HStack/Spacer
        var nodes: [ViewNode] = []

        // Title bar background
        nodes.append(
            RoundedRectangle(cornerRadius: 0).fill(bg).frame(width: w, height: h)
        )

        // Traffic lights — positioned explicitly
        let btnY = WindowChrome.buttonInsetY
        let btnX = WindowChrome.buttonInsetX
        let btnSize = WindowChrome.buttonSize
        let btnStep = btnSize + WindowChrome.buttonSpacing

        nodes.append(trafficLightButton(color: isFocused ? .red : .gray, symbol: showSymbols ? "×" : nil)
            .padding(.top, btnY).padding(.leading, btnX))
        nodes.append(trafficLightButton(color: isFocused ? .yellow : .gray, symbol: showSymbols ? "−" : nil)
            .padding(.top, btnY).padding(.leading, btnX + btnStep))
        nodes.append(trafficLightButton(color: isFocused ? .green : .gray, symbol: showSymbols ? (window.isMaximized ? "↙" : "↗") : nil)
            .padding(.top, btnY).padding(.leading, btnX + btnStep * 2))

        // Title text — centered
        let titleColor = isFocused ? Color.primary : Color.secondary
        nodes.append(
            Text(window.title).font(.system(size: 13)).foregroundColor(titleColor)
                .padding(.top, (h - 13) / 2)
                .padding(.leading, w / 2 - CGFloat(window.title.count) * 4)
        )

        return ViewNode.zstack(children: nodes).frame(width: w, height: h)
    }

    private func trafficLightButton(color: Color, symbol: String?) -> ViewNode {
        let size = WindowChrome.buttonSize
        if let symbol {
            return ZStack {
                RoundedRectangle(cornerRadius: size / 2)
                    .fill(color)
                    .frame(width: size, height: size)
                Text(symbol)
                    .font(.system(size: size * 0.7, weight: .bold))
                    .foregroundColor(Color(r: 0, g: 0, b: 0, a: 0.5))
            }
            .frame(width: size, height: size)
        } else {
            return RoundedRectangle(cornerRadius: size / 2)
                .fill(color)
                .frame(width: size, height: size)
        }
    }
}
