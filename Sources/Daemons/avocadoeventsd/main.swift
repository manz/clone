import Foundation
import AvocadoEvents
import CloneProtocol

// Ignore SIGPIPE — clients may disconnect before we finish writing responses.
signal(SIGPIPE, SIG_IGN)

let server = AvocadoEventsServer()
do {
    try server.start()
    fputs("avocadoeventsd: listening on \(avocadoeventsdSocketPath)\n", stderr)
} catch {
    fputs("avocadoeventsd: failed to start: \(error)\n", stderr)
    exit(1)
}
dispatchMain()
