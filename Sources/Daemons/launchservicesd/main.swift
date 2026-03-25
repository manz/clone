import Foundation
import CloneLaunchServices
import CloneProtocol
import AvocadoEvents

let server = LaunchServicesServer()
do {
    try server.start()
    fputs("launchservicesd: listening on \(launchservicesdSocketPath)\n", stderr)
    fputs("launchservicesd: scanning \(cloneApplicationsPath)\n", stderr)
} catch {
    fputs("launchservicesd: failed to start: \(error)\n", stderr)
    exit(1)
}

// Connect to avocadoeventsd to receive launch requests from apps (e.g. Dock)
DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
    let aeClient = AvocadoEventsClient()
    do {
        try aeClient.connect()
        aeClient.register(appId: "com.clone.launchservicesd")
        aeClient.onEvent = { event in
            switch event {
            case .launchApp(let bundleId):
                fputs("launchservicesd: launch request via AvocadoEvent for \(bundleId)\n", stderr)
                let lsClient = LaunchServicesClient()
                do {
                    try lsClient.connect()
                    if lsClient.launch(bundleIdentifier: bundleId) == nil {
                        fputs("launchservicesd: app not found: \(bundleId)\n", stderr)
                    }
                    lsClient.disconnect()
                } catch {
                    fputs("launchservicesd: failed to self-connect: \(error)\n", stderr)
                }
            default:
                break
            }
        }
        DispatchQueue.global().async { aeClient.listen() }
        fputs("launchservicesd: connected to avocadoeventsd\n", stderr)
    } catch {
        fputs("launchservicesd: could not connect to avocadoeventsd: \(error)\n", stderr)
    }
}

dispatchMain()
