import Foundation
import DesktopKit

/// Converts DesktopKit FlatRenderCommand to UniFFI RenderCommand.
public enum Bridge {
    public static func toEngineCommands(_ flatCommands: [FlatRenderCommand]) -> [RenderCommand] {
        flatCommands.map { cmd in
            switch cmd.kind {
            case .rect(let color):
                return .rect(
                    x: cmd.x, y: cmd.y, w: cmd.width, h: cmd.height,
                    color: color.toEngine()
                )
            case .roundedRect(let radius, let color):
                return .roundedRect(
                    x: cmd.x, y: cmd.y, w: cmd.width, h: cmd.height,
                    radius: radius, color: color.toEngine()
                )
            case .text(let content, let fontSize, let color, let weight):
                return .text(
                    x: cmd.x, y: cmd.y,
                    content: content, fontSize: fontSize,
                    color: color.toEngine(),
                    weight: weight.toEngine()
                )
            }
        }
    }
}

extension DesktopColor {
    func toEngine() -> RgbaColor {
        RgbaColor(r: r, g: g, b: b, a: a)
    }
}

extension DesktopKit.FontWeight {
    func toEngine() -> FontWeight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}

/// Swift-side delegate that builds the full DesktopKit UI and returns render commands to Rust.
public final class SwiftDesktopDelegate: DesktopDelegate {
    private var mouseX: Double = 0
    private var mouseY: Double = 0
    private var showFinder: Bool = false
    private let finderEntries: [Finder.FileEntry]

    public init() {
        // Sample file entries for the Finder
        self.finderEntries = [
            Finder.FileEntry(name: "Applications", isDirectory: true),
            Finder.FileEntry(name: "Documents", isDirectory: true),
            Finder.FileEntry(name: "Downloads", isDirectory: true),
            Finder.FileEntry(name: "Desktop", isDirectory: true),
            Finder.FileEntry(name: "Music", isDirectory: true),
            Finder.FileEntry(name: "Pictures", isDirectory: true),
            Finder.FileEntry(name: "readme.txt", isDirectory: false, size: 1234),
            Finder.FileEntry(name: "notes.md", isDirectory: false, size: 5678),
            Finder.FileEntry(name: "photo.jpg", isDirectory: false, size: 2_500_000),
        ]
    }

    public func onFrame(surfaceId: UInt64, width: UInt32, height: UInt32) -> [RenderCommand] {
        GeometryReaderRegistry.shared.clear()

        let w = Float(width)
        let h = Float(height)

        // Build the desktop
        let desktop = Desktop(
            screenWidth: w,
            screenHeight: h,
            mouseX: Float(mouseX),
            mouseY: Float(mouseY)
        )

        // Menu bar
        let menuBar = MenuBar(screenWidth: w, appName: "Finder", clock: currentTime())

        // Build full scene
        var tree: ViewNode = ZStack {
            desktop.body()
            VStack(alignment: .leading, spacing: 0) {
                menuBar.body()
                Spacer()
            }
        }

        // Add Finder if toggled
        if showFinder {
            let finder = Finder(
                width: 600,
                height: 400,
                currentPath: "/Users/manz",
                entries: finderEntries
            )
            tree = ZStack {
                tree
                finder.body()
                    .padding(.top, 50)
                    .padding(.leading, (w - 600) / 2)
            }
        }

        // Layout pass
        let layoutResult = Layout.layout(tree, in: LayoutFrame(x: 0, y: 0, width: w, height: h))
        let flatCommands = CommandFlattener.flatten(layoutResult)

        return Bridge.toEngineCommands(flatCommands)
    }

    public func onPointerMove(surfaceId: UInt64, x: Double, y: Double) {
        mouseX = x
        mouseY = y
    }

    public func onPointerButton(surfaceId: UInt64, button: UInt32, pressed: Bool) {
        // Left click toggles finder for demo
        if button == 0 && pressed {
            showFinder.toggle()
        }
    }

    public func onKey(surfaceId: UInt64, keycode: UInt32, pressed: Bool) {
        // 'f' key (keycode varies) toggles finder
        if keycode == 9 && pressed { // 'f' on most layouts
            showFinder.toggle()
        }
    }

    private func currentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}

/// Launch the desktop. Call from main.swift.
public func launchDesktop() throws {
    let delegate = SwiftDesktopDelegate()
    try runDesktop(delegate: delegate)
}
