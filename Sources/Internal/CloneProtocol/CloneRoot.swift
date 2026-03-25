import Foundation

/// Root directory for all Clone runtime data.
/// Override with `CLONE_ROOT` environment variable.
public let cloneRoot: String = {
    if let env = ProcessInfo.processInfo.environment["CLONE_ROOT"] {
        return env
    }
    return NSString(string: "~/.clone").expandingTildeInPath
}()

/// Installed .app bundles.
public let cloneApplicationsPath: String = "\(cloneRoot)/Applications"

/// System binaries (compositor + daemons).
public let cloneSystemPath: String = "\(cloneRoot)/System"

/// Library root for all scoped data (preferences, caches, app support).
public let cloneLibraryPath: String = "\(cloneRoot)/Library"

/// @AppStorage plist files, dock pinned list, etc.
public let clonePreferencesPath: String = "\(cloneRoot)/Library/Preferences"

/// Per-app cache directories.
public let cloneCachesPath: String = "\(cloneRoot)/Library/Caches"

/// Per-app support directory (SwiftData, documents, etc.)
public func cloneAppSupportPath(bundleId: String) -> String {
    "\(cloneRoot)/Library/Application Support/\(bundleId)"
}
