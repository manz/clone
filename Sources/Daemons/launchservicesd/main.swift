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
                fputs("launchservicesd: launch request for \(bundleId)\n", stderr)
                // Check if the app is already running via a separate AE connection
                let queryClient = AvocadoEventsClient()
                do {
                    try queryClient.connect()
                    if queryClient.isRegistered(appId: bundleId) {
                        // App is running — send activate instead of spawning
                        fputs("launchservicesd: \(bundleId) already running, sending activate\n", stderr)
                        queryClient.send(to: bundleId, event: .activate)
                    } else {
                        // App not running — launch via LaunchServices
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
                    }
                    queryClient.disconnect()
                } catch {
                    fputs("launchservicesd: failed to query avocadoeventsd: \(error)\n", stderr)
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
