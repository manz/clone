import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Header layout at the start of the shared memory segment.
///
/// Offset | Field           | Size
/// -------|-----------------|-----
///   0    | magic           |  4   (0xC10EFACE)
///   4    | version         |  4   (1)
///   8    | width           |  4
///  12    | height          |  4
///  16    | stride          |  4   (bytes per row, 64-byte aligned)
///  20    | frontBuffer     |  4   (0 or 1)
///  24    | frameSequence   |  8
///  32    | dirty           |  4   (1 = new frame available)
///  36    | reserved        | 28
///  64    | buffer 0        | stride * height
///        | buffer 1        | stride * height
private let kHeaderSize = 64
private let kMagic: UInt32 = 0xC10E_FACE
private let kVersion: UInt32 = 1

private let kOffsetMagic = 0
private let kOffsetVersion = 4
private let kOffsetWidth = 8
private let kOffsetHeight = 12
private let kOffsetStride = 16
private let kOffsetFrontBuffer = 20
private let kOffsetFrameSequence = 24
private let kOffsetDirty = 32

/// Double-buffered shared memory surface for cross-process pixel transport.
///
/// Uses a memory-mapped temp file (`/tmp/clone-surface-*`) for cross-process
/// sharing. The creator (app) writes BGRA8 pixels into the back buffer, then
/// calls `flip()` to swap it to the front. The reader (compositor) reads from
/// the front buffer.
public final class SharedSurface {
    public let name: String
    public private(set) var width: Int
    public private(set) var height: Int
    public private(set) var stride: Int

    private var fd: Int32 = -1
    private var ptr: UnsafeMutableRawPointer?
    private var mappedSize: Int = 0
    private let isCreator: Bool

    /// The file path backing this surface.
    public var path: String { "/tmp/\(name)" }

    /// Create (app side) or open (compositor side) a shared memory surface.
    ///
    /// - Parameters:
    ///   - name: Surface name (becomes `/tmp/<name>`)
    ///   - width: Surface width in pixels
    ///   - height: Surface height in pixels
    ///   - create: `true` to create (app), `false` to open existing (compositor)
    public init?(name: String, width: Int, height: Int, create: Bool) {
        self.name = name
        self.width = width
        self.height = height
        self.stride = SharedSurface.alignedStride(width: width)
        self.isCreator = create

        let filePath = "/tmp/\(name)"
        let flags: Int32 = create ? (O_CREAT | O_RDWR | O_TRUNC) : O_RDWR

        fd = open(filePath, flags, 0o600)
        guard fd >= 0 else { return nil }

        let totalSize = Self.totalSize(stride: stride, height: height)

        if create {
            guard ftruncate(fd, off_t(totalSize)) == 0 else {
                close(fd)
                unlink(filePath)
                return nil
            }
        }

        let mapped = mmap(nil, totalSize, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0)
        guard mapped != MAP_FAILED else {
            close(fd)
            if create { unlink(filePath) }
            return nil
        }

        ptr = mapped
        mappedSize = totalSize

        if create {
            writeHeader()
        }
    }

    deinit {
        if let ptr {
            munmap(ptr, mappedSize)
        }
        if fd >= 0 {
            close(fd)
        }
        if isCreator {
            unlink(path)
        }
    }

    // MARK: - Header access

    private func writeHeader() {
        guard let ptr else { return }
        ptr.storeBytes(of: kMagic, toByteOffset: kOffsetMagic, as: UInt32.self)
        ptr.storeBytes(of: kVersion, toByteOffset: kOffsetVersion, as: UInt32.self)
        ptr.storeBytes(of: UInt32(width), toByteOffset: kOffsetWidth, as: UInt32.self)
        ptr.storeBytes(of: UInt32(height), toByteOffset: kOffsetHeight, as: UInt32.self)
        ptr.storeBytes(of: UInt32(stride), toByteOffset: kOffsetStride, as: UInt32.self)
        ptr.storeBytes(of: UInt32(0), toByteOffset: kOffsetFrontBuffer, as: UInt32.self)
        ptr.storeBytes(of: UInt64(0), toByteOffset: kOffsetFrameSequence, as: UInt64.self)
        ptr.storeBytes(of: UInt32(0), toByteOffset: kOffsetDirty, as: UInt32.self)
    }

    /// Validate the magic number (compositor side).
    public var isValid: Bool {
        guard let ptr else { return false }
        let magic = ptr.load(fromByteOffset: kOffsetMagic, as: UInt32.self)
        return magic == kMagic
    }

    /// Read width from the header (compositor side, for validation).
    public var headerWidth: Int {
        guard let ptr else { return 0 }
        return Int(ptr.load(fromByteOffset: kOffsetWidth, as: UInt32.self))
    }

    /// Read height from the header (compositor side, for validation).
    public var headerHeight: Int {
        guard let ptr else { return 0 }
        return Int(ptr.load(fromByteOffset: kOffsetHeight, as: UInt32.self))
    }

    /// The current front buffer index (0 or 1).
    public var frontBufferIndex: Int {
        guard let ptr else { return 0 }
        return Int(ptr.load(fromByteOffset: kOffsetFrontBuffer, as: UInt32.self))
    }

    /// The frame sequence number (incremented on each flip).
    public var frameSequence: UInt64 {
        guard let ptr else { return 0 }
        return ptr.load(fromByteOffset: kOffsetFrameSequence, as: UInt64.self)
    }

    /// Whether a new frame is available (compositor side).
    public var isDirty: Bool {
        guard let ptr else { return false }
        return ptr.load(fromByteOffset: kOffsetDirty, as: UInt32.self) != 0
    }

    /// Clear the dirty flag (compositor side, after reading the front buffer).
    public func clearDirty() {
        guard let ptr else { return }
        ptr.storeBytes(of: UInt32(0), toByteOffset: kOffsetDirty, as: UInt32.self)
    }

    // MARK: - Buffer access

    /// Pointer to the back buffer for rendering (app side).
    /// The app renders into this buffer, then calls `flip()`.
    public func backBuffer() -> UnsafeMutableRawPointer? {
        guard let ptr else { return nil }
        let front = frontBufferIndex
        let back = 1 - front
        let bufSize = stride * height
        return ptr + kHeaderSize + back * bufSize
    }

    /// Pointer to the front buffer for reading (compositor side).
    /// The compositor reads from this buffer after checking `isDirty`.
    public func frontBuffer() -> UnsafeRawPointer? {
        guard let ptr else { return nil }
        let front = frontBufferIndex
        let bufSize = stride * height
        return UnsafeRawPointer(ptr + kHeaderSize + front * bufSize)
    }

    /// Swap front/back buffers after rendering is complete (app side).
    /// Sets the dirty flag and increments the frame sequence.
    public func flip() {
        guard let ptr else { return }
        let front = frontBufferIndex
        let newFront = UInt32(1 - front)

        // Memory fence before making the buffer visible
        OSMemoryBarrier()

        ptr.storeBytes(of: newFront, toByteOffset: kOffsetFrontBuffer, as: UInt32.self)
        let seq = ptr.load(fromByteOffset: kOffsetFrameSequence, as: UInt64.self)
        ptr.storeBytes(of: seq + 1, toByteOffset: kOffsetFrameSequence, as: UInt64.self)
        ptr.storeBytes(of: UInt32(1), toByteOffset: kOffsetDirty, as: UInt32.self)
    }

    // MARK: - Resize

    /// Resize the surface. Recreates the mapping.
    /// The creator should call this, then notify the reader to re-open.
    public func resize(width: Int, height: Int) -> Bool {
        guard let oldPtr = ptr else { return false }

        let newStride = SharedSurface.alignedStride(width: width)
        let newSize = Self.totalSize(stride: newStride, height: height)

        munmap(oldPtr, mappedSize)

        if isCreator {
            guard ftruncate(fd, off_t(newSize)) == 0 else { return false }
        }

        let mapped = mmap(nil, newSize, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0)
        guard mapped != MAP_FAILED else { return false }

        self.ptr = mapped
        self.mappedSize = newSize
        self.width = width
        self.height = height
        self.stride = newStride

        if isCreator {
            writeHeader()
        }

        return true
    }

    // MARK: - Helpers

    /// Bytes per row, aligned to 64 bytes for cache-line friendliness.
    public static func alignedStride(width: Int) -> Int {
        let unpadded = width * 4
        return (unpadded + 63) & ~63
    }

    private static func totalSize(stride: Int, height: Int) -> Int {
        kHeaderSize + stride * height * 2
    }

    /// The total byte size of one buffer (stride * height).
    public var bufferSize: Int {
        stride * height
    }
}
