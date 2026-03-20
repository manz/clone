import Foundation

/// A part of an app's user interface with a life cycle managed by the system.
@MainActor
public protocol Scene {
    associatedtype Body: Scene
    var body: Body { get }
}

/// Terminal scene — used by concrete scene types like WindowGroup.
public struct _NeverScene: Scene {
    public var body: _NeverScene { fatalError() }
}

/// Builds scenes from result-builder syntax.
@resultBuilder
public struct SceneBuilder {
    public static func buildBlock<S: Scene>(_ scene: S) -> S {
        scene
    }
}

// MARK: - Scene modifiers

extension Scene {
    /// `.commands { }` — attaches command menus to the scene. No-op on Clone.
    public func commands(@ViewBuilder content: () -> some View) -> some Scene { self }

    /// `.defaultSize(width:height:)` — sets the default window size. No-op on Clone.
    public func defaultSize(width: CGFloat, height: CGFloat) -> some Scene { self }

    /// `.windowStyle(_:)` — sets the window style. No-op on Clone.
    public func windowStyle<S>(_ style: S) -> some Scene { self }

    /// `.windowResizability(_:)` — sets the window resizability. No-op on Clone.
    public func windowResizability(_ resizability: WindowResizability) -> some Scene { self }
}

/// Window resizability options.
public struct WindowResizability: Sendable {
    public static let automatic = WindowResizability()
    public static let contentSize = WindowResizability()
    public static let contentMinSize = WindowResizability()
}

/// Window style types.
public struct HiddenTitleBarWindowStyle { public init() {} }
public struct DefaultWindowStyle { public init() {} }
public struct TitleBarWindowStyle { public init() {} }
