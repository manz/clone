import Foundation
import IOSurface
import CoreGraphics
import ImageIO

/// Captures a downscaled PNG thumbnail from an IOSurface.
/// Must be called from a background thread — IOSurfaceLock waits for the GPU to flush.
enum ThumbnailCapture {
    static func capture(iosurfaceId: UInt32, maxWidth: UInt32, maxHeight: UInt32) -> (width: UInt32, height: UInt32, pngData: Data)? {
        guard let surface = IOSurfaceLookup(iosurfaceId) else { return nil }

        let srcW = IOSurfaceGetWidth(surface)
        let srcH = IOSurfaceGetHeight(surface)
        let bytesPerRow = IOSurfaceGetBytesPerRow(surface)
        guard srcW > 0 && srcH > 0 && bytesPerRow > 0 else { return nil }

        let scale = min(Double(maxWidth) / Double(srcW), Double(maxHeight) / Double(srcH), 1.0)
        let dstW = Int(max(Double(srcW) * scale, 1))
        let dstH = Int(max(Double(srcH) * scale, 1))

        IOSurfaceLock(surface, .readOnly, nil)
        defer { IOSurfaceUnlock(surface, .readOnly, nil) }

        let baseAddr = IOSurfaceGetBaseAddress(surface)
        let src = baseAddr.assumingMemoryBound(to: UInt8.self)

        // Downsample BGRA → RGBA into a CGContext, then encode as PNG
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: dstW,
            height: dstH,
            bitsPerComponent: 8,
            bytesPerRow: dstW * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        guard let dstPtr = ctx.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        for dy in 0..<dstH {
            let sy = dy * srcH / dstH
            for dx in 0..<dstW {
                let sx = dx * srcW / dstW
                let srcIdx = sy * bytesPerRow + sx * 4
                let dstIdx = (dy * dstW + dx) * 4
                dstPtr[dstIdx + 0] = src[srcIdx + 2] // R from B
                dstPtr[dstIdx + 1] = src[srcIdx + 1] // G
                dstPtr[dstIdx + 2] = src[srcIdx + 0] // B from R
                dstPtr[dstIdx + 3] = src[srcIdx + 3] // A
            }
        }

        guard let cgImage = ctx.makeImage() else { return nil }

        // Encode as PNG
        let pngData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(pngData as CFMutableData, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }

        return (UInt32(dstW), UInt32(dstH), pngData as Data)
    }
}
