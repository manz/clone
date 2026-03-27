import Testing
@testable import SharedSurface

@Suite("SharedSurface")
struct SharedSurfaceTests {

    @Test func createAndValidate() {
        let surface = SharedSurface(name: "clone-test-create", width: 100, height: 80, create: true)
        #expect(surface != nil)
        #expect(surface!.isValid)
        #expect(surface!.width == 100)
        #expect(surface!.height == 80)
        #expect(surface!.headerWidth == 100)
        #expect(surface!.headerHeight == 80)
    }

    @Test func strideAlignment() {
        // 100 pixels * 4 bytes = 400 bytes, aligned to 64 → 448
        #expect(SharedSurface.alignedStride(width: 100) == 448)
        // 16 pixels * 4 = 64, already aligned
        #expect(SharedSurface.alignedStride(width: 16) == 64)
        // 1 pixel * 4 = 4, aligned to 64
        #expect(SharedSurface.alignedStride(width: 1) == 64)
    }

    @Test func backBufferWritable() {
        let surface = SharedSurface(name: "clone-test-write", width: 10, height: 10, create: true)!
        let back = surface.backBuffer()!

        // Write BGRA pixel (blue=255, green=0, red=0, alpha=255)
        back.storeBytes(of: UInt8(255), toByteOffset: 0, as: UInt8.self) // B
        back.storeBytes(of: UInt8(0), toByteOffset: 1, as: UInt8.self)   // G
        back.storeBytes(of: UInt8(0), toByteOffset: 2, as: UInt8.self)   // R
        back.storeBytes(of: UInt8(255), toByteOffset: 3, as: UInt8.self) // A

        let b = back.load(fromByteOffset: 0, as: UInt8.self)
        #expect(b == 255)
    }

    @Test func flipSwapsBuffers() {
        let surface = SharedSurface(name: "clone-test-flip", width: 10, height: 10, create: true)!

        #expect(surface.frontBufferIndex == 0)
        #expect(surface.frameSequence == 0)
        #expect(surface.isDirty == false)

        surface.flip()

        #expect(surface.frontBufferIndex == 1)
        #expect(surface.frameSequence == 1)
        #expect(surface.isDirty == true)

        surface.clearDirty()
        #expect(surface.isDirty == false)

        surface.flip()
        #expect(surface.frontBufferIndex == 0)
        #expect(surface.frameSequence == 2)
    }

    @Test func crossProcessReadWrite() {
        let name = "clone-test-crossproc"
        let width = 4
        let height = 2
        let stride = SharedSurface.alignedStride(width: width)

        // Creator (app side)
        let writer = SharedSurface(name: name, width: width, height: height, create: true)!

        // Write a pattern into the back buffer
        let back = writer.backBuffer()!
        for i in 0..<(width * 4) {
            back.storeBytes(of: UInt8(i & 0xFF), toByteOffset: i, as: UInt8.self)
        }
        writer.flip()

        // Reader (compositor side) opens the same file
        let reader = SharedSurface(name: name, width: width, height: height, create: false)!
        #expect(reader.isValid)
        #expect(reader.isDirty)

        // Read from front buffer and verify
        let front = reader.frontBuffer()!
        for i in 0..<(width * 4) {
            let byte = front.load(fromByteOffset: i, as: UInt8.self)
            #expect(byte == UInt8(i & 0xFF))
        }

        reader.clearDirty()
        #expect(reader.isDirty == false)
    }

    @Test func resize() {
        let surface = SharedSurface(name: "clone-test-resize", width: 50, height: 50, create: true)!
        #expect(surface.width == 50)

        let ok = surface.resize(width: 200, height: 100)
        #expect(ok)
        #expect(surface.width == 200)
        #expect(surface.height == 100)
        #expect(surface.headerWidth == 200)
        #expect(surface.headerHeight == 100)
        #expect(surface.isValid)
    }

    @Test func bufferSize() {
        let surface = SharedSurface(name: "clone-test-bufsize", width: 100, height: 80, create: true)!
        let expectedStride = SharedSurface.alignedStride(width: 100)
        #expect(surface.bufferSize == expectedStride * 80)
    }
}
