import XCTest
import Foundation
@testable import CloneClient
@testable import CloneProtocol

/// Tests for the wire protocol and AppClient message reading.
/// Uses socketpair + direct poll() to avoid runLoop's main thread dispatch issues in tests.
final class AppClientReadLoopTests: XCTestCase {

    // MARK: - Helpers

    private func makeSocketPair() throws -> (Int32, Int32) {
        var fds: [Int32] = [0, 0]
        guard socketpair(AF_UNIX, SOCK_STREAM, 0, &fds) == 0 else {
            throw NSError(domain: "socketpair", code: -1)
        }
        return (fds[0], fds[1])
    }

    private func writeAll(fd: Int32, _ data: Data) {
        data.withUnsafeBytes { ptr in
            var written = 0
            while written < data.count {
                let n = write(fd, ptr.baseAddress! + written, data.count - written)
                if n <= 0 { break }
                written += n
            }
        }
    }

    private func encode(_ msg: CompositorMessage) throws -> Data {
        try WireProtocol.encode(msg)
    }

    // MARK: - WireProtocol encode/decode

    func testWireProtocolRoundTrip() throws {
        let msg = CompositorMessage.pointerMove(x: 42.5, y: 99.0)
        let data = try encode(msg)

        // Length prefix + JSON
        XCTAssertTrue(data.count > 4)
        let length = data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        XCTAssertEqual(Int(length) + 4, data.count)

        // Decode
        guard let (decoded, consumed) = WireProtocol.decode(CompositorMessage.self, from: data) else {
            XCTFail("Decode returned nil"); return
        }
        XCTAssertEqual(consumed, data.count)
        if case .pointerMove(let x, let y) = decoded {
            XCTAssertEqual(x, 42.5)
            XCTAssertEqual(y, 99.0)
        } else {
            XCTFail("Wrong message type: \(decoded)")
        }
    }

    func testWireProtocolPartialBufferReturnsNil() throws {
        let data = try encode(.pointerMove(x: 1, y: 2))
        // Only give it half the data
        let partial = data.subdata(in: 0..<data.count / 2)
        let result = WireProtocol.decode(CompositorMessage.self, from: partial)
        XCTAssertNil(result)
    }

    func testWireProtocolTwoByteBufferReturnsNil() {
        let tiny = Data([0x00, 0x00])
        let result = WireProtocol.decode(CompositorMessage.self, from: tiny)
        XCTAssertNil(result)
    }

    func testWireProtocolMultipleMessagesInBuffer() throws {
        var buffer = Data()
        buffer.append(try encode(.pointerMove(x: 1, y: 2)))
        buffer.append(try encode(.pointerMove(x: 3, y: 4)))
        buffer.append(try encode(.pointerMove(x: 5, y: 6)))

        var decoded: [CompositorMessage] = []
        while let (msg, consumed) = WireProtocol.decode(CompositorMessage.self, from: buffer) {
            buffer = buffer.subdata(in: consumed..<buffer.count)
            decoded.append(msg)
        }
        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(buffer.count, 0)
    }

    func testWireProtocolMessageWithTrailingPartial() throws {
        let full = try encode(.pointerMove(x: 10, y: 20))
        let nextFull = try encode(.pointerMove(x: 30, y: 40))
        var buffer = Data()
        buffer.append(full)
        buffer.append(nextFull.subdata(in: 0..<10)) // partial second message

        var decoded: [CompositorMessage] = []
        while let (msg, consumed) = WireProtocol.decode(CompositorMessage.self, from: buffer) {
            buffer = buffer.subdata(in: consumed..<buffer.count)
            decoded.append(msg)
        }
        XCTAssertEqual(decoded.count, 1) // only the first complete one
        XCTAssertEqual(buffer.count, 10) // partial remains
    }

    func testWireProtocolPngThumbnailMessage() throws {
        // Simulate a small PNG payload
        let fakePng = Data(repeating: 0xAB, count: 2048)
        let msg = CompositorMessage.windowThumbnail(windowId: 7, pngData: fakePng)
        let data = try encode(msg)

        XCTAssertTrue(data.count < 10_000, "Wire data too large: \(data.count)")

        guard let (decoded, consumed) = WireProtocol.decode(CompositorMessage.self, from: data) else {
            XCTFail("Failed to decode thumbnail message"); return
        }
        XCTAssertEqual(consumed, data.count)
        if case .windowThumbnail(let wid, let png) = decoded {
            XCTAssertEqual(wid, 7)
            XCTAssertEqual(png.count, fakePng.count)
            XCTAssertEqual(png, fakePng)
        } else {
            XCTFail("Wrong message type")
        }
    }


}
