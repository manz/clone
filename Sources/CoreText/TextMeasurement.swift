import Foundation
import clone_engineFFI

/// Text size result from cosmic-text measurement.
public struct CTTextSize: Sendable {
    public let width: CGFloat
    public let height: CGFloat
}

/// Font weight for text measurement — matches the Rust engine's FontWeight enum.
public enum CTFontWeight: Int, Sendable {
    case regular = 0
    case medium = 1
    case semibold = 2
    case bold = 3
}

/// Measures text using cosmic-text (the same shaping engine the Rust renderer uses).
/// This module sits below both SwiftUI and EngineBridge — no dependency cycles.
public enum CTTextMeasurer {
    /// Measure text with the given font size and weight.
    public static func measure(_ text: String, fontSize: CGFloat, weight: CTFontWeight, isIcon: Bool = false) -> CTTextSize {
        guard !text.isEmpty else {
            return CTTextSize(width: 0, height: fontSize * 1.2)
        }

        var status = RustCallStatus()

        // Encode string as RustBuffer (UniFFI format: 4-byte big-endian length + UTF-8 bytes)
        let contentBuf = lowerString(text)

        // Encode FontWeight enum as RustBuffer (UniFFI format: 4-byte big-endian variant index, 1-based)
        let weightBuf = lowerEnum(weight.rawValue + 1)

        let resultBuf = uniffi_clone_engine_fn_func_measure_text(
            contentBuf,
            Float(fontSize),
            weightBuf,
            isIcon ? 1 : 0,
            &status
        )

        guard status.code == 0 else {
            return CTTextSize(width: fontSize * 0.55 * CGFloat(text.count), height: fontSize * 1.2)
        }

        // Decode TextSize { width: f32, height: f32 } — two big-endian f32s
        let data = Data(UnsafeBufferPointer(start: resultBuf.data, count: Int(resultBuf.len)))
        let w = readFloat(data, offset: 0)
        let h = readFloat(data, offset: 4)
        var freeStatus = RustCallStatus()
        ffi_clone_engine_rustbuffer_free(resultBuf, &freeStatus)

        return CTTextSize(width: CGFloat(w), height: CGFloat(h))
    }

    // MARK: - FFI Encoding

    private static func lowerString(_ value: String) -> RustBuffer {
        let utf8 = Array(value.utf8)
        var bytes = [UInt8](repeating: 0, count: 4 + utf8.count)
        let len = Int32(utf8.count).bigEndian
        withUnsafeBytes(of: len) { for i in 0..<4 { bytes[i] = $0[i] } }
        for i in 0..<utf8.count { bytes[4 + i] = utf8[i] }
        return allocBuffer(bytes)
    }

    private static func lowerEnum(_ variant: Int) -> RustBuffer {
        var bytes = [UInt8](repeating: 0, count: 4)
        let v = Int32(variant).bigEndian
        withUnsafeBytes(of: v) { for i in 0..<4 { bytes[i] = $0[i] } }
        return allocBuffer(bytes)
    }

    private static func allocBuffer(_ bytes: [UInt8]) -> RustBuffer {
        var status = RustCallStatus()
        let buf = ffi_clone_engine_rustbuffer_alloc(UInt64(bytes.count), &status)
        bytes.withUnsafeBufferPointer { src in
            buf.data!.update(from: src.baseAddress!, count: bytes.count)
        }
        return RustBuffer(capacity: buf.capacity, len: UInt64(bytes.count), data: buf.data)
    }

    private static func readFloat(_ data: Data, offset: Int) -> Float {
        let b0 = UInt32(data[offset]) << 24
        let b1 = UInt32(data[offset + 1]) << 16
        let b2 = UInt32(data[offset + 2]) << 8
        let b3 = UInt32(data[offset + 3])
        return Float(bitPattern: b0 | b1 | b2 | b3)
    }
}
