import Foundation
import PosixShim
import CloneLaunchServices
import CloneProtocol
import AvocadoEvents

let server = LaunchServicesServer()
do {
    try server.start()
    logErr("launchservicesd: listening on \(launchservicesdSocketPath)\n")
    logErr("launchservicesd: scanning \(cloneApplicationsPath)\n")
} catch {
    logErr("launchservicesd: failed to start: \(error)\n")
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
                logErr("launchservicesd: launch request for \(bundleId)\n")
                // Check if the app is already running via a separate AE connection
                let queryClient = AvocadoEventsClient()
                do {
                    try queryClient.connect()
                    if queryClient.isRegistered(appId: bundleId) {
                        // App is running — send activate instead of spawning
                        logErr("launchservicesd: \(bundleId) already running, sending activate\n")
                        queryClient.send(to: bundleId, event: .activate)
                    } else {
                        // App not running — launch via LaunchServices
                        let lsClient = LaunchServicesClient()
                        do {
                            try lsClient.connect()
                            if lsClient.launch(bundleIdentifier: bundleId) == nil {
                                logErr("launchservicesd: app not found: \(bundleId)\n")
                            }
                            lsClient.disconnect()
                        } catch {
                            logErr("launchservicesd: failed to self-connect: \(error)\n")
                        }
                    }
                    queryClient.disconnect()
                } catch {
                    logErr("launchservicesd: failed to query avocadoeventsd: \(error)\n")
                }
            default:
                break
            }
        }
        DispatchQueue.global().async { aeClient.listen() }
        logErr("launchservicesd: connected to avocadoeventsd\n")
    } catch {
        logErr("launchservicesd: could not connect to avocadoeventsd: \(error)\n")
    }
}

dispatchMain()
