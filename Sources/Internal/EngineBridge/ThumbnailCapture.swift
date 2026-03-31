import Foundation
import CoreGraphics
#if canImport(IOSurface)
import IOSurface
#endif

/// Captures a downscaled PNG thumbnail from raw pixel data or an IOSurface.
enum ThumbnailCapture {

    /// Capture from raw BGRA8 pixel data (cross-platform).
    static func capture(bgra: Data, srcW: Int, srcH: Int, srcBytesPerRow: Int,
                        maxWidth: UInt32, maxHeight: UInt32) -> (width: UInt32, height: UInt32, pngData: Data)? {
        guard srcW > 0, srcH > 0 else { return nil }

        let scale = min(Double(maxWidth) / Double(srcW), Double(maxHeight) / Double(srcH), 1.0)
        let dstW = max(Int(Double(srcW) * scale), 1)
        let dstH = max(Int(Double(srcH) * scale), 1)

        guard let ctx = CGContext(data: nil, width: dstW, height: dstH,
                                  bitsPerComponent: 8, bytesPerRow: dstW * 4,
                                  space: CGColorSpace(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        guard let dstPtr = ctx.data?.assumingMemoryBound(to: UInt8.self) else { return nil }

        bgra.withUnsafeBytes { srcBuf in
            guard let src = srcBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for dy in 0..<dstH {
                let sy = dy * srcH / dstH
                for dx in 0..<dstW {
                    let sx = dx * srcW / dstW
                    let srcIdx = sy * srcBytesPerRow + sx * 4
                    let dstIdx = (dy * dstW + dx) * 4
                    dstPtr[dstIdx + 0] = src[srcIdx + 2] // R from B
                    dstPtr[dstIdx + 1] = src[srcIdx + 1] // G
                    dstPtr[dstIdx + 2] = src[srcIdx + 0] // B from R
                    dstPtr[dstIdx + 3] = src[srcIdx + 3] // A
                }
            }
        }

        guard let image = ctx.makeImage(), let pngData = image.pngData() else { return nil }
        return (UInt32(dstW), UInt32(dstH), pngData)
    }

    #if canImport(IOSurface)
    /// Capture from an IOSurface (macOS only).
    static func capture(iosurfaceId: UInt32, maxWidth: UInt32, maxHeight: UInt32) -> (width: UInt32, height: UInt32, pngData: Data)? {
        guard let surface = IOSurfaceLookup(iosurfaceId) else { return nil }

        let srcW = IOSurfaceGetWidth(surface)
        let srcH = IOSurfaceGetHeight(surface)
        let bytesPerRow = IOSurfaceGetBytesPerRow(surface)
        guard srcW > 0, srcH > 0, bytesPerRow > 0 else { return nil }

        IOSurfaceLock(surface, .readOnly, nil)
        defer { IOSurfaceUnlock(surface, .readOnly, nil) }

        let baseAddr = IOSurfaceGetBaseAddress(surface)
        let data = Data(bytes: baseAddr, count: bytesPerRow * srcH)

        return capture(bgra: data, srcW: srcW, srcH: srcH, srcBytesPerRow: bytesPerRow,
                       maxWidth: maxWidth, maxHeight: maxHeight)
    }
    #endif
}
