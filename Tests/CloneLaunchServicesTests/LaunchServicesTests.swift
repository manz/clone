import Testing
import Foundation
import CloneProtocol
@testable import CloneLaunchServices

@Test func serverStartsAndStops() throws {
    let tempDir = NSTemporaryDirectory() + "clone-lsd-test-\(ProcessInfo.processInfo.processIdentifier)"
    let socketPath = tempDir + "/test-lsd.sock"
    try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tempDir) }

    let server = LaunchServicesServer(socketPath: socketPath, scanDirectories: [])
    try server.start()
    #expect(FileManager.default.fileExists(atPath: socketPath))
    server.stop()
}

@Test func clientConnectsToServer() throws {
    let tempDir = NSTemporaryDirectory() + "clone-lsd-test-connect-\(ProcessInfo.processInfo.processIdentifier)"
    let socketPath = tempDir + "/test-lsd.sock"
    try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tempDir) }

    let server = LaunchServicesServer(socketPath: socketPath, scanDirectories: [])
    try server.start()
    defer { server.stop() }

    let client = LaunchServicesClient(socketPath: socketPath)
    try client.connect()
    defer { client.disconnect() }

    // No apps registered (empty scan dirs)
    let apps = client.allApps()
    #expect(apps.isEmpty)
}

@Test func serverScansAppBundles() throws {
    let tempDir = NSTemporaryDirectory() + "clone-lsd-test-scan-\(ProcessInfo.processInfo.processIdentifier)"
    let socketPath = tempDir + "/test-lsd.sock"
    let appsDir = tempDir + "/Applications"
    try FileManager.default.createDirectory(atPath: appsDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tempDir) }

    // Create a fake .app bundle
    let appDir = "\(appsDir)/TestApp.app/Contents"
    try FileManager.default.createDirectory(atPath: "\(appDir)/MacOS", withIntermediateDirectories: true)
    let plist: [String: Any] = [
        "CFBundleIdentifier": "com.test.app",
        "CFBundleName": "TestApp",
        "CFBundleDisplayName": "Test Application",
        "CFBundleExecutable": "TestApp",
        "CFBundlePackageType": "APPL",
        "CFBundleDocumentTypes": [
            [
                "CFBundleTypeName": "Text Files",
                "CFBundleTypeExtensions": ["txt", "md"],
                "LSItemContentTypes": ["public.plain-text"],
                "CFBundleTypeRole": "Editor",
            ] as [String: Any]
        ] as [[String: Any]],
    ]
    let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    try data.write(to: URL(fileURLWithPath: "\(appDir)/Info.plist"))
    // Write a dummy executable
    try Data().write(to: URL(fileURLWithPath: "\(appDir)/MacOS/TestApp"))

    let server = LaunchServicesServer(socketPath: socketPath, scanDirectories: [])
    try server.start()
    defer { server.stop() }

    let client = LaunchServicesClient(socketPath: socketPath)
    try client.connect()
    defer { client.disconnect() }

    // Scan the test apps directory
    client.scan(directories: [appsDir])
    // Small delay for server to process
    Thread.sleep(forTimeInterval: 0.1)

    // Query by bundle ID
    let reg = client.appInfo(bundleIdentifier: "com.test.app")
    #expect(reg != nil)
    #expect(reg?.displayName == "Test Application")
    #expect(reg?.documentTypes.count == 1)
    #expect(reg?.documentTypes.first?.extensions.contains("txt") == true)

    // Query by extension
    let txtApp = client.defaultApp(forExtension: "txt")
    #expect(txtApp?.bundleIdentifier == "com.test.app")

    let mdApp = client.defaultApp(forExtension: "md")
    #expect(mdApp?.bundleIdentifier == "com.test.app")

    // Unknown extension
    let unknown = client.defaultApp(forExtension: "xyz")
    #expect(unknown == nil)
}

@Test func appRegistrationCodable() throws {
    let reg = AppRegistration(
        bundleIdentifier: "com.test.app",
        bundleName: "TestApp",
        displayName: "Test Application",
        executablePath: "/usr/bin/test",
        bundlePath: "/Applications/TestApp.app",
        iconFile: "AppIcon",
        version: "1.0",
        documentTypes: [
            DocumentTypeInfo(name: "Text", extensions: ["txt"], utis: ["public.plain-text"], role: "Editor")
        ]
    )

    let encoded = try JSONEncoder().encode(reg)
    let decoded = try JSONDecoder().decode(AppRegistration.self, from: encoded)
    #expect(decoded == reg)
}

@Test func lsdRequestResponseCodable() throws {
    let requests: [LSDRequest] = [
        .allApps,
        .defaultApp(forExtension: "txt"),
        .appInfo(bundleIdentifier: "com.test"),
        .scan(directories: ["/tmp"]),
        .register(path: "/Applications/Test.app"),
    ]

    for req in requests {
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(LSDRequest.self, from: data)
        // Just verify round-trip doesn't crash
        _ = decoded
    }

    let responses: [LSDResponse] = [
        .scanComplete(count: 5),
        .app(nil),
        .apps([]),
        .error("test error"),
    ]

    for resp in responses {
        let data = try JSONEncoder().encode(resp)
        let decoded = try JSONDecoder().decode(LSDResponse.self, from: data)
        _ = decoded
    }
}

@Test func cloneRootPathsExist() {
    #expect(!cloneRoot.isEmpty)
    #expect(cloneApplicationsPath.contains("Applications"))
    #expect(cloneSystemPath.contains("System"))
    #expect(clonePreferencesPath.contains("Preferences"))
    #expect(cloneCachesPath.contains("Caches"))
    #expect(cloneAppSupportPath(bundleId: "com.test").contains("com.test"))
}
