import Testing
import Foundation
@testable import CloneDaemon
import CloneProtocol

// MARK: - Helpers

/// Connect to the daemon socket and return the fd.
private func connectToDaemon(socketPath: String) -> Int32 {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return -1 }

    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    socketPath.withCString { ptr in
        withUnsafeMutablePointer(to: &addr.sun_path) { pathPtr in
            pathPtr.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
                _ = strlcpy(dest, ptr, 104)
            }
        }
    }

    let result = withUnsafePointer(to: &addr) { ptr in
        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
            Darwin.connect(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }
    guard result == 0 else {
        Darwin.close(fd)
        return -1
    }
    return fd
}

private func sendRequest(_ fd: Int32, _ request: DaemonRequest) {
    guard let data = try? WireProtocol.encode(request) else { return }
    data.withUnsafeBytes { ptr in
        _ = Darwin.write(fd, ptr.baseAddress!, data.count)
    }
}

private func readResponse(_ fd: Int32, timeout: TimeInterval = 1.0) -> DaemonResponse? {
    let flags = fcntl(fd, F_GETFL)
    _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

    var buffer = Data()
    let deadline = Date().addingTimeInterval(timeout)

    while Date() < deadline {
        var buf = [UInt8](repeating: 0, count: 4096)
        let n = Darwin.read(fd, &buf, buf.count)
        if n > 0 {
            buffer.append(contentsOf: buf[0..<n])
        }
        if let (msg, _) = WireProtocol.decode(DaemonResponse.self, from: buffer) {
            return msg
        }
        usleep(10_000) // 10ms
    }
    return nil
}

/// Unique socket path per test to avoid collisions.
private func testSocketPath() -> String {
    "/tmp/clone-daemon-test-\(UUID().uuidString.prefix(8)).sock"
}

// MARK: - Protocol encoding tests

@Test func nowPlayingInfoRoundTrips() throws {
    let info = NowPlayingInfo(
        title: "Starlight", artist: "Muse", albumTitle: "Black Holes",
        playbackDuration: 240, elapsedPlaybackTime: 42, playbackRate: 1.0,
        appId: "com.test.music"
    )
    let data = try WireProtocol.encode(info)
    let (decoded, consumed) = WireProtocol.decode(NowPlayingInfo.self, from: data)!
    #expect(decoded == info)
    #expect(consumed == data.count)
}

@Test func daemonRequestRoundTrips() throws {
    let info = NowPlayingInfo(title: "Song", appId: "app")
    let requests: [DaemonRequest] = [
        .publishNowPlaying(info),
        .clearNowPlaying,
        .remoteCommand(.togglePlayPause),
        .observe,
    ]
    for request in requests {
        let data = try WireProtocol.encode(request)
        let (decoded, _) = WireProtocol.decode(DaemonRequest.self, from: data)!
        switch (request, decoded) {
        case (.publishNowPlaying(let a), .publishNowPlaying(let b)):
            #expect(a == b)
        case (.clearNowPlaying, .clearNowPlaying):
            break
        case (.remoteCommand(let a), .remoteCommand(let b)):
            #expect(a == b)
        case (.observe, .observe):
            break
        default:
            Issue.record("Request round-trip mismatch")
        }
    }
}

@Test func daemonResponseRoundTrips() throws {
    let info = NowPlayingInfo(title: "Song", artist: "Band", appId: "app")
    let responses: [DaemonResponse] = [
        .nowPlayingChanged(info),
        .nowPlayingChanged(nil),
        .remoteCommand(.play),
    ]
    for response in responses {
        let data = try WireProtocol.encode(response)
        let (decoded, _) = WireProtocol.decode(DaemonResponse.self, from: data)!
        switch (response, decoded) {
        case (.nowPlayingChanged(let a), .nowPlayingChanged(let b)):
            #expect(a == b)
        case (.remoteCommand(let a), .remoteCommand(let b)):
            #expect(a == b)
        default:
            Issue.record("Response round-trip mismatch")
        }
    }
}

// MARK: - DaemonServer integration tests

@Test func serverStartsAndAcceptsConnections() throws {
    let path = testSocketPath()
    let server = DaemonServer(socketPath: path)
    try server.start()
    defer { server.stop() }

    usleep(50_000)
    let fd = connectToDaemon(socketPath: path)
    #expect(fd >= 0)
    Darwin.close(fd)
}

@Test func observerReceivesCurrentStateOnSubscribe() throws {
    let path = testSocketPath()
    let server = DaemonServer(socketPath: path)
    try server.start()
    defer { server.stop() }
    usleep(50_000)

    // Publisher sends now-playing
    let pubFd = connectToDaemon(socketPath: path)
    #expect(pubFd >= 0)
    defer { Darwin.close(pubFd) }

    let info = NowPlayingInfo(title: "Test Song", artist: "Test Artist", appId: "com.test")
    sendRequest(pubFd, .publishNowPlaying(info))
    usleep(100_000) // let server process

    // Observer connects and subscribes
    let obsFd = connectToDaemon(socketPath: path)
    #expect(obsFd >= 0)
    defer { Darwin.close(obsFd) }

    sendRequest(obsFd, .observe)
    let response = readResponse(obsFd)

    guard case .nowPlayingChanged(let received) = response else {
        Issue.record("Expected nowPlayingChanged, got \(String(describing: response))")
        return
    }
    #expect(received == info)
}

@Test func observerReceivesNilWhenNothingPlaying() throws {
    let path = testSocketPath()
    let server = DaemonServer(socketPath: path)
    try server.start()
    defer { server.stop() }
    usleep(50_000)

    let obsFd = connectToDaemon(socketPath: path)
    #expect(obsFd >= 0)
    defer { Darwin.close(obsFd) }

    sendRequest(obsFd, .observe)
    let response = readResponse(obsFd)

    guard case .nowPlayingChanged(let received) = response else {
        Issue.record("Expected nowPlayingChanged, got \(String(describing: response))")
        return
    }
    #expect(received == nil)
}

@Test func publishBroadcastsToObservers() throws {
    let path = testSocketPath()
    let server = DaemonServer(socketPath: path)
    try server.start()
    defer { server.stop() }
    usleep(50_000)

    // Observer subscribes first
    let obsFd = connectToDaemon(socketPath: path)
    #expect(obsFd >= 0)
    defer { Darwin.close(obsFd) }
    sendRequest(obsFd, .observe)
    // Drain initial nil
    _ = readResponse(obsFd)

    // Publisher publishes
    let pubFd = connectToDaemon(socketPath: path)
    #expect(pubFd >= 0)
    defer { Darwin.close(pubFd) }

    let info = NowPlayingInfo(title: "New Song", artist: "Artist", playbackRate: 1.0, appId: "pub")
    sendRequest(pubFd, .publishNowPlaying(info))

    let response = readResponse(obsFd)
    guard case .nowPlayingChanged(let received) = response else {
        Issue.record("Expected nowPlayingChanged broadcast")
        return
    }
    #expect(received == info)
}

@Test func clearNowPlayingNotifiesObservers() throws {
    let path = testSocketPath()
    let server = DaemonServer(socketPath: path)
    try server.start()
    defer { server.stop() }
    usleep(50_000)

    // Observer subscribes
    let obsFd = connectToDaemon(socketPath: path)
    #expect(obsFd >= 0)
    defer { Darwin.close(obsFd) }
    sendRequest(obsFd, .observe)
    _ = readResponse(obsFd)

    // Publisher publishes then clears
    let pubFd = connectToDaemon(socketPath: path)
    #expect(pubFd >= 0)
    defer { Darwin.close(pubFd) }

    let info = NowPlayingInfo(title: "Song", appId: "pub")
    sendRequest(pubFd, .publishNowPlaying(info))
    _ = readResponse(obsFd) // drain the publish

    sendRequest(pubFd, .clearNowPlaying)
    let response = readResponse(obsFd)
    guard case .nowPlayingChanged(let received) = response else {
        Issue.record("Expected nowPlayingChanged(nil)")
        return
    }
    #expect(received == nil)
}

@Test func remoteCommandForwardedToPublisher() throws {
    let path = testSocketPath()
    let server = DaemonServer(socketPath: path)
    try server.start()
    defer { server.stop() }
    usleep(50_000)

    // Publisher connects and publishes
    let pubFd = connectToDaemon(socketPath: path)
    #expect(pubFd >= 0)
    defer { Darwin.close(pubFd) }

    let info = NowPlayingInfo(title: "Song", appId: "pub")
    sendRequest(pubFd, .publishNowPlaying(info))
    usleep(100_000)

    // Observer sends remote command
    let obsFd = connectToDaemon(socketPath: path)
    #expect(obsFd >= 0)
    defer { Darwin.close(obsFd) }

    sendRequest(obsFd, .remoteCommand(.nextTrack))

    // Publisher should receive the command
    let response = readResponse(pubFd)
    guard case .remoteCommand(let cmd) = response else {
        Issue.record("Expected remoteCommand, got \(String(describing: response))")
        return
    }
    #expect(cmd == .nextTrack)
}

@Test func publisherDisconnectClearsNowPlaying() throws {
    let path = testSocketPath()
    let server = DaemonServer(socketPath: path)
    try server.start()
    defer { server.stop() }
    usleep(50_000)

    // Observer subscribes
    let obsFd = connectToDaemon(socketPath: path)
    #expect(obsFd >= 0)
    defer { Darwin.close(obsFd) }
    sendRequest(obsFd, .observe)
    _ = readResponse(obsFd)

    // Publisher publishes then disconnects
    let pubFd = connectToDaemon(socketPath: path)
    #expect(pubFd >= 0)

    let info = NowPlayingInfo(title: "Song", appId: "pub")
    sendRequest(pubFd, .publishNowPlaying(info))
    _ = readResponse(obsFd) // drain publish broadcast

    Darwin.close(pubFd) // disconnect publisher
    usleep(200_000)

    let response = readResponse(obsFd)
    guard case .nowPlayingChanged(let received) = response else {
        Issue.record("Expected nowPlayingChanged(nil) on publisher disconnect")
        return
    }
    #expect(received == nil)
}

@Test func allRemoteCommandsEncode() throws {
    let commands: [RemoteCommand] = [.play, .pause, .togglePlayPause, .nextTrack, .previousTrack]
    for cmd in commands {
        let data = try WireProtocol.encode(DaemonRequest.remoteCommand(cmd))
        let (decoded, _) = WireProtocol.decode(DaemonRequest.self, from: data)!
        if case .remoteCommand(let roundTripped) = decoded {
            #expect(roundTripped == cmd)
        } else {
            Issue.record("Failed to round-trip \(cmd)")
        }
    }
}
