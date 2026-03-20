// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Clone",
    platforms: [.macOS(.v14)],
    products: [
        // Public SDK products — external apps depend on these
        .library(name: "SwiftUI", targets: ["SwiftUI"]),
        .library(name: "SwiftData", targets: ["SwiftData"]),
        .library(name: "AppKit", targets: ["AppKit"]),
    ],
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
        // AppKit shim — NSColor and other AppKit types for Linux
        .target(
            name: "AppKit",
            dependencies: [],
            path: "Sources/AppKit"
        ),
        // UI DSL framework
        .target(
            name: "SwiftUI",
            dependencies: ["AppKit", "CloneClient", "CloneProtocol"],
            path: "Sources/SwiftUI",
            exclude: ["Generated"]
        ),
        // UniFFI bridge to Rust GPU engine
        .target(
            name: "EngineBridge",
            dependencies: ["clone_engineFFI", "SwiftUI", "CloneServer", "CloneProtocol"],
            path: "Sources/EngineBridge"
        ),
        // Compositor main binary
        .executableTarget(
            name: "CloneDesktop",
            dependencies: ["SwiftUI", "EngineBridge", "CloneServer"],
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
            dependencies: ["SwiftUI"],
            path: "Sources/FinderApp"
        ),
        // Settings app (separate process)
        .executableTarget(
            name: "Settings",
            dependencies: ["SwiftUI"],
            path: "Sources/SettingsApp"
        ),
        // Dock app (separate process)
        .executableTarget(
            name: "Dock",
            dependencies: ["SwiftUI"],
            path: "Sources/DockApp"
        ),
        // MenuBar app (separate process)
        .executableTarget(
            name: "MenuBar",
            dependencies: ["SwiftUI"],
            path: "Sources/MenuBarApp"
        ),
        .testTarget(
            name: "SwiftUITests",
            dependencies: ["SwiftUI"],
            path: "Tests/SwiftUITests"
        ),
        .systemLibrary(
            name: "CSQLite",
            path: "Sources/CSQLite",
            pkgConfig: "sqlite3"
        ),
        .target(
            name: "SwiftData",
            dependencies: ["CSQLite"],
            path: "Sources/SwiftData"
        ),
        .testTarget(
            name: "SwiftDataTests",
            dependencies: ["SwiftData"],
            path: "Tests/SwiftDataTests"
        ),
        // ycodebuild — CLI tool for building external apps against Aquax SDK
        .executableTarget(
            name: "ycodebuild",
            path: "Sources/ycodebuild"
        ),
    ]
)
