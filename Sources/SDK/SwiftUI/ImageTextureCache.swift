import Foundation
import CloneProtocol

/// Tracks registered GPU textures for raster images.
/// Ensures RegisterTexture is emitted exactly once per texture ID,
/// avoiding megabytes of pixel data flowing through every frame.
public final class ImageTextureCache: @unchecked Sendable {
    public static let shared = ImageTextureCache()
    private init() {}

    /// Texture IDs that have been registered with the GPU.
    private var registered: Set<UInt64> = []
    /// Pending registrations to emit on the next frame.
    private var pending: [(textureId: UInt64, width: UInt32, height: UInt32, rgbaData: [UInt8])] = []

    public func isRegistered(_ textureId: UInt64) -> Bool {
        registered.contains(textureId)
    }

    public func register(textureId: UInt64, width: UInt32, height: UInt32, rgbaData: [UInt8]) {
        guard !registered.contains(textureId) else { return }
        registered.insert(textureId)
        pending.append((textureId, width, height, rgbaData))
    }

    /// Drain pending registrations as IPC commands (call once per frame, before the main command list).
    public func drainPending() -> [IPCRenderCommand] {
        guard !pending.isEmpty else { return [] }
        let cmds = pending.map { IPCRenderCommand.registerTexture(textureId: $0.textureId, width: $0.width, height: $0.height, rgbaData: $0.rgbaData) }
        pending.removeAll()
        return cmds
    }
}
