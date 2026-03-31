// Cross-platform POSIX wrappers for socket I/O.
// On macOS these resolve to Darwin; on Linux to Glibc.
// Avoids `Darwin.connect`, `Darwin.read` etc. scattered across the codebase.

import Foundation
@_exported import CPosixShim

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

// MARK: - Logging

/// Write a message to stderr. Thread-safe wrapper that avoids Swift 6 concurrency
/// warnings about `stderr` being shared mutable state.
public func logErr(_ message: String) {
    FileHandle.standardError.write(Data(message.utf8))
}

// MARK: - App bundle platform directory

/// The platform-specific subdirectory inside Contents/ for app bundle executables.
/// `Contents/MacOS` on macOS, `Contents/Linux` on Linux.
#if canImport(Darwin)
public let cloneAppBundleExecDir = "MacOS"
#else
public let cloneAppBundleExecDir = "Linux"
#endif

// MARK: - Socket I/O

public let posix_connect = connect
public let posix_close   = close
public let posix_read    = read
public let posix_write   = write
public let posix_accept  = accept
public let posix_bind    = bind
public let posix_listen  = listen

// MARK: - SOCK_STREAM (enum on Linux, Int32 on macOS)

#if canImport(Darwin)
public let CLONE_SOCK_STREAM: Int32 = SOCK_STREAM
#else
public let CLONE_SOCK_STREAM: Int32 = Int32(SOCK_STREAM.rawValue)
#endif

// MARK: - SCM_RIGHTS: send/receive file descriptors over Unix sockets

/// Send data with an attached file descriptor via SCM_RIGHTS.
/// The fd is duplicated by the kernel — caller should close their copy after.
public func posix_sendmsg_fd(_ sock: Int32, _ data: UnsafeRawPointer, _ len: Int, _ fd: Int32) -> Int32 {
    Int32(clone_sendmsg_fd(sock, data, len, fd))
}

/// Receive data with an optional attached file descriptor via SCM_RIGHTS.
/// Returns (bytesRead, receivedFd). receivedFd is -1 if no fd was attached.
public func posix_recvmsg_fd(_ sock: Int32, _ buf: UnsafeMutableRawPointer, _ len: Int) -> (Int32, Int32) {
    var receivedFd: Int32 = -1
    let n = Int32(clone_recvmsg_fd(sock, buf, len, &receivedFd))
    return (n, receivedFd)
}

// MARK: - macOS: Mach port ↔ file descriptor (via fileport)

#if canImport(Darwin)
// MARK: - macOS: Mach port transfer via bootstrap server

/// Register a Mach receive port with the bootstrap server.
/// The compositor calls this to create a channel for receiving IOSurface ports.
public func posix_mach_register_port(_ name: String) -> (success: Bool, recvPort: UInt32) {
    var port: UInt32 = 0
    let result = clone_mach_register_port(name, &port)
    return (result == 0, port)
}

/// Look up a Mach send port by name from the bootstrap server.
/// Apps call this to get the compositor's surface channel.
public func posix_mach_lookup_port(_ name: String) -> (success: Bool, sendPort: UInt32) {
    var port: UInt32 = 0
    let result = clone_mach_lookup_port(name, &port)
    return (result == 0, port)
}

/// Send a Mach port right to a destination port.
public func posix_mach_send_port(dest: UInt32, port: UInt32) -> Bool {
    clone_mach_send_port(dest, port) == 0
}

/// Receive a Mach port right (blocking).
public func posix_mach_recv_port(recvPort: UInt32) -> (success: Bool, port: UInt32) {
    var port: UInt32 = 0
    let result = clone_mach_recv_port(recvPort, &port)
    return (result == 0, port)
}
#endif
