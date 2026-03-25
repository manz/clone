import Foundation
import CloneLaunchServices
import CloneProtocol

let server = LaunchServicesServer()
do {
    try server.start()
    fputs("launchservicesd: listening on \(launchservicesdSocketPath)\n", stderr)
    fputs("launchservicesd: scanning \(cloneApplicationsPath)\n", stderr)
} catch {
    fputs("launchservicesd: failed to start: \(error)\n", stderr)
    exit(1)
}
dispatchMain()
