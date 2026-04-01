import Foundation
import PosixShim
import CloneKeychain
import CloneProtocol

let server = KeychainServer()

do {
    try server.start()
    logErr("keychaind: listening on \(keychainSocketPath)\n")
} catch {
    logErr("keychaind: failed to start — \(error)\n")
    exit(1)
}

// Block main thread — GCD handles I/O
dispatchMain()
