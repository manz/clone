import Foundation
import PosixShim
import AvocadoEvents
import CloneProtocol

// Ignore SIGPIPE — clients may disconnect before we finish writing responses.
signal(SIGPIPE, SIG_IGN)

let server = AvocadoEventsServer()
do {
    try server.start()
    logErr("avocadoeventsd: listening on \(avocadoeventsdSocketPath)\n")
} catch {
    logErr("avocadoeventsd: failed to start: \(error)\n")
    exit(1)
}
dispatchMain()
