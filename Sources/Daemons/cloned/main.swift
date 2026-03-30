import Foundation
import PosixShim
import CloneDaemon
import CloneProtocol

let server = DaemonServer()

do {
    try server.start()
    logErr("cloned: listening on \(daemonSocketPath)\n")
} catch {
    logErr("cloned: failed to start — \(error)\n")
    exit(1)
}

// Block main thread — GCD handles I/O
dispatchMain()
