// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Clone",
    platforms: [.macOS(.v14)],
    targets: [
        .systemLibrary(
            name: "clone_engineFFI",
            path: "Sources/CEngine"
        ),
        // Shared IPC protocol
        .target(
            name: "CloneProtocol",
            path: "Sources/CloneProtocol"
        ),
        // Compositor-side server
        .target(
            name: "CloneServer",
            dependencies: ["CloneProtocol"],
            path: "Sources/CloneServer"
        ),
        // App-side client library
        .target(
            name: "CloneClient",
            dependencies: ["CloneProtocol"],
            path: "Sources/CloneClient"
        ),
        // UI DSL framework
        .target(
            name: "DesktopKit",
            dependencies: [],
            path: "Sources/DesktopKit",
            exclude: ["Generated"]
        ),
        // UniFFI bridge to Rust GPU engine
        .target(
            name: "EngineBridge",
            dependencies: ["clone_engineFFI", "DesktopKit", "CloneServer", "CloneProtocol"],
            path: "Sources/EngineBridge"
        ),
        // Compositor main binary
        .executableTarget(
            name: "CloneDesktop",
            dependencies: ["DesktopKit", "EngineBridge", "CloneServer"],
            path: "Sources/Apps",
            linkerSettings: [
                .unsafeFlags([
                    "-L", "target/debug",
                    "-lclone_engine",
                    "-Xlinker", "-rpath", "-Xlinker", "target/debug",
                ]),
            ]
        ),
        // Finder app (separate process)
        .executableTarget(
            name: "Finder",
            dependencies: ["CloneClient", "CloneProtocol"],
            path: "Sources/FinderApp"
        ),
        // Settings app (separate process)
        .executableTarget(
            name: "Settings",
            dependencies: ["CloneClient", "CloneProtocol"],
            path: "Sources/SettingsApp"
        ),
        .testTarget(
            name: "DesktopKitTests",
            dependencies: ["DesktopKit"],
            path: "Tests/DesktopKitTests"
        ),
    ]
)
