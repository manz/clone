import Foundation
import CloneKeychain
import CloneProtocol

let server = KeychainServer()

do {
    try server.start()
    fputs("keychaind: listening on \(keychainSocketPath)\n", stderr)
} catch {
    fputs("keychaind: failed to start — \(error)\n", stderr)
    exit(1)
}

// Block main thread — GCD handles I/O
dispatchMain()
