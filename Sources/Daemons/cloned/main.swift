import Foundation
import CloneDaemon
import CloneProtocol

let server = DaemonServer()

do {
    try server.start()
    fputs("cloned: listening on \(daemonSocketPath)\n", stderr)
} catch {
    fputs("cloned: failed to start — \(error)\n", stderr)
    exit(1)
}

// Block main thread — GCD handles I/O
dispatchMain()
