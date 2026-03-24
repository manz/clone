// Cross-platform POSIX wrappers for socket I/O.
// On macOS these resolve to Darwin; on Linux to Glibc.
// Avoids `Darwin.connect`, `Darwin.read` etc. scattered across the codebase.

import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
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
