/// A part of an app's user interface with a life cycle managed by the system.
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
