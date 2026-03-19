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

    public init(id: UInt64, appId: String, title: String, x: Float, y: Float, width: Float, height: Float) {
        self.id = id
        self.appId = appId
        self.title = title
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.isVisible = true
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
}

/// Manages all windows: z-ordering, focus, movement, lifecycle.
public final class WindowManager {
    /// Windows in z-order (last = topmost).
    public private(set) var windows: [ManagedWindow] = []
    public private(set) var focusedWindowId: UInt64? = nil
    private var nextWindowId: UInt64 = 1

    // Drag state
    private var dragWindowId: UInt64? = nil
    private var dragOffsetX: Float = 0
    private var dragOffsetY: Float = 0

    public init() {}

    // MARK: - Lifecycle

    /// Open a new window. Returns its ID.
    @discardableResult
    public func open(appId: String, title: String, x: Float, y: Float, width: Float, height: Float) -> UInt64 {
        let id = nextWindowId
        nextWindowId += 1
        let window = ManagedWindow(id: id, appId: appId, title: title, x: x, y: y, width: width, height: height)
        windows.append(window)
        focusedWindowId = id
        return id
    }

    /// Close a window by ID.
    public func close(id: UInt64) {
        windows.removeAll { $0.id == id }
        if focusedWindowId == id {
            focusedWindowId = windows.last?.id
        }
    }

    /// Bring a window to front and focus it.
    public func focus(id: UInt64) {
        guard let idx = windows.firstIndex(where: { $0.id == id }) else { return }
        let window = windows.remove(at: idx)
        windows.append(window)
        focusedWindowId = id
    }

    // MARK: - Hit testing

    /// Find the topmost window under the point. Returns nil if no window.
    public func windowAt(x: Float, y: Float) -> ManagedWindow? {
        // Back-to-front: last window is topmost
        for window in windows.reversed() {
            if window.isVisible && window.contains(px: x, py: y) {
                return window
            }
        }
        return nil
    }

    /// Check if point hits the close button of a window.
    public func hitsCloseButton(windowId: UInt64, x: Float, y: Float) -> Bool {
        guard let window = windows.first(where: { $0.id == windowId }) else { return false }
        let bx = window.x + WindowChrome.buttonInsetX
        let by = window.y + WindowChrome.buttonInsetY
        let r = WindowChrome.buttonSize / 2
        let dx = x - (bx + r)
        let dy = y - (by + r)
        return (dx * dx + dy * dy) <= (r * r) * 4 // generous hit area
    }

    // MARK: - Dragging

    /// Begin dragging a window from the title bar.
    public func beginDrag(windowId: UInt64, mouseX: Float, mouseY: Float) {
        guard let window = windows.first(where: { $0.id == windowId }) else { return }
        dragWindowId = windowId
        dragOffsetX = mouseX - window.x
        dragOffsetY = mouseY - window.y
        focus(id: windowId)
    }

    /// Update drag position.
    public func updateDrag(mouseX: Float, mouseY: Float) {
        guard let id = dragWindowId,
              let idx = windows.firstIndex(where: { $0.id == id }) else { return }
        windows[idx].x = mouseX - dragOffsetX
        windows[idx].y = mouseY - dragOffsetY
    }

    /// End dragging.
    public func endDrag() {
        dragWindowId = nil
    }

    public var isDragging: Bool { dragWindowId != nil }

    // MARK: - Rendering

    /// Build the view tree for all visible windows with their content.
    public func render(contentProvider: (ManagedWindow) -> ViewNode) -> [ViewNode] {
        windows.filter(\.isVisible).map { window in
            let content = contentProvider(window)
            let isFocused = window.id == focusedWindowId
            return windowChrome(window: window, isFocused: isFocused, content: content)
        }
    }

    private func windowChrome(window: ManagedWindow, isFocused: Bool, content: ViewNode) -> ViewNode {
        let shadowAlpha: Float = isFocused ? 0.4 : 0.2

        return ViewNode.padding(
            EdgeInsets(top: window.y, leading: window.x, bottom: 0, trailing: 0),
            child: ZStack {
                // Shadow
                RoundedRectangle(cornerRadius: WindowChrome.cornerRadius)
                    .fill(DesktopColor(r: 0, g: 0, b: 0, a: shadowAlpha))
                    .frame(width: window.width + 8, height: window.height + 8)
                    .padding(.top, -4)
                    .padding(.leading, -4)
                // Window background
                RoundedRectangle(cornerRadius: WindowChrome.cornerRadius)
                    .fill(isFocused ? .surface : DesktopColor(r: 0.16, g: 0.15, b: 0.21))
                    .frame(width: window.width, height: window.height)
                // Content area
                VStack(alignment: .leading, spacing: 0) {
                    // Title bar
                    titleBar(window: window, isFocused: isFocused)
                    // App content
                    content
                }
            }
        )
    }

    private func titleBar(window: ManagedWindow, isFocused: Bool) -> ViewNode {
        ZStack {
            // Title bar background
            RoundedRectangle(cornerRadius: 0)
                .fill(isFocused ? .overlay : DesktopColor(r: 0.19, g: 0.17, b: 0.24))
                .frame(width: window.width, height: WindowChrome.titleBarHeight)
            HStack(spacing: WindowChrome.buttonSpacing) {
                // Traffic lights
                RoundedRectangle(cornerRadius: WindowChrome.buttonSize / 2)
                    .fill(isFocused ? .systemRed : .muted)
                    .frame(width: WindowChrome.buttonSize, height: WindowChrome.buttonSize)
                RoundedRectangle(cornerRadius: WindowChrome.buttonSize / 2)
                    .fill(isFocused ? .systemYellow : .muted)
                    .frame(width: WindowChrome.buttonSize, height: WindowChrome.buttonSize)
                RoundedRectangle(cornerRadius: WindowChrome.buttonSize / 2)
                    .fill(isFocused ? .systemGreen : .muted)
                    .frame(width: WindowChrome.buttonSize, height: WindowChrome.buttonSize)
                Spacer()
                Text(window.title).fontSize(13).foregroundColor(isFocused ? .text : .subtle)
                Spacer()
            }
        }
        .frame(width: window.width, height: WindowChrome.titleBarHeight)
    }
}
