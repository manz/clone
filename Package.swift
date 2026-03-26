// swift-tools-version: 6.2
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Clone",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        // Public SDK products — external apps depend on these
        // AppKit is exposed transitively via SwiftUI (not listed here to avoid
        // shadowing macOS's real AppKit in the dependency resolver)
        .library(name: "QuartzCore", targets: ["QuartzCore"]),
        .library(name: "SwiftUI", targets: ["SwiftUI"]),
        .library(name: "SwiftData", targets: ["SwiftData"]),
        // Stub modules for Apple frameworks Clone doesn't implement
        .library(name: "Charts", targets: ["Charts"]),
        .library(name: "MediaPlayer", targets: ["MediaPlayer"]),
        .library(name: "AVKit", targets: ["AVKit"]),
        .library(name: "UniformTypeIdentifiers", targets: ["UniformTypeIdentifiers"]),
        .library(name: "AVFoundation", targets: ["AVFoundation"]),
        // On macOS, Foundation imports the system Security.framework, so we
        // can't name our target "Security" without a circular dep. On Linux
        // (where there is no system Security) this will be renamed to "Security".
        .library(name: "KeychainServices", targets: ["KeychainServices"]),
        // Internal shared library — promoted to framework for transitive linking
        .library(name: "PosixShim", targets: ["PosixShim"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        // ── FFI ─────────────────────────────────────────────────
        .systemLibrary(
            name: "clone_engineFFI",
            path: "Sources/FFI/CEngine"
        ),
        .systemLibrary(
            name: "clone_audioFFI",
            path: "Sources/FFI/CAudio"
        ),
        .systemLibrary(
            name: "clone_textFFI",
            path: "Sources/FFI/CText"
        ),
        .systemLibrary(
            name: "clone_renderFFI",
            path: "Sources/FFI/CRender"
        ),
        .systemLibrary(
            name: "CSQLite",
            path: "Sources/FFI/CSQLite",
            pkgConfig: "sqlite3"
        ),

        .target(
            name: "CPosixShim",
            path: "Sources/FFI/CPosixShim",
            publicHeadersPath: "include"
        ),

        // ── Internal ────────────────────────────────────────────
        .target(
            name: "PosixShim",
            dependencies: ["CPosixShim"],
            path: "Sources/Internal/PosixShim"
        ),
        .target(
            name: "SharedSurface",
            path: "Sources/Internal/SharedSurface"
        ),
        .target(
            name: "CloneRender",
            dependencies: ["clone_renderFFI"],
            path: "Sources/Internal/CloneRender",
            linkerSettings: [
                .unsafeFlags([
                    "-L", "/Users/manz/Projects/clone/target/debug",
                    "-lclone_render",
                    "-Xlinker", "-rpath", "-Xlinker", "/Users/manz/Projects/clone/target/debug",
                ]),
            ]
        ),
        .target(
            name: "CloneProtocol",
            dependencies: ["PosixShim"],
            path: "Sources/Internal/CloneProtocol"
        ),
        .target(
            name: "CloneServer",
            dependencies: ["CloneProtocol", "PosixShim"],
            path: "Sources/Internal/CloneServer"
        ),
        .target(
            name: "CloneClient",
            dependencies: ["CloneProtocol", "PosixShim"],
            path: "Sources/Internal/CloneClient"
        ),
        .target(
            name: "AudioBridge",
            dependencies: ["clone_audioFFI"],
            path: "Sources/Internal/AudioBridge",
            linkerSettings: [
                .unsafeFlags([
                    "-L", "/Users/manz/Projects/clone/target/debug",
                    "-lclone_audio",
                    "-Xlinker", "-rpath", "-Xlinker", "/Users/manz/Projects/clone/target/debug",
                ]),
            ]
        ),
        .target(
            name: "CloneText",
            dependencies: ["clone_textFFI"],
            path: "Sources/Internal/CloneText",
            linkerSettings: [
                .unsafeFlags([
                    "-L", "/Users/manz/Projects/clone/target/debug",
                    "-lclone_text",
                    "-Xlinker", "-rpath", "-Xlinker", "/Users/manz/Projects/clone/target/debug",
                ]),
            ]
        ),
        .target(
            name: "EngineBridge",
            dependencies: ["clone_engineFFI", "SwiftUI", "CloneServer", "CloneProtocol", "CloneLaunchServices"],
            path: "Sources/Internal/EngineBridge"
        ),
        .macro(
            name: "SwiftDataMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            path: "Sources/Internal/SwiftDataMacros"
        ),

        // ── SDK ─────────────────────────────────────────────────
        .target(
            name: "QuartzCore",
            dependencies: [],
            path: "Sources/SDK/QuartzCore"
        ),
        .target(
            name: "AppKit",
            dependencies: ["QuartzCore"],
            path: "Sources/SDK/AppKit"
        ),
        .target(
            name: "SwiftUI",
            dependencies: ["AppKit", "CloneClient", "CloneProtocol", "SwiftDataMacros", "CloneText", "UniformTypeIdentifiers", "AvocadoEvents", "CloneLaunchServices", "CloneRender", "SharedSurface"],
            path: "Sources/SDK/SwiftUI",
            exclude: ["Generated"]
        ),
        .target(
            name: "SwiftData",
            dependencies: ["CSQLite", "SwiftDataMacros", "CloneProtocol"],
            path: "Sources/SDK/SwiftData"
        ),
        .target(
            name: "Charts",
            dependencies: ["SwiftUI"],
            path: "Sources/SDK/Charts"
        ),
        .target(
            name: "MediaPlayer",
            dependencies: ["CloneProtocol", "PosixShim"],
            path: "Sources/SDK/MediaPlayer"
        ),
        .target(
            name: "AVKit",
            path: "Sources/SDK/AVKit"
        ),
        .target(
            name: "AVFoundation",
            dependencies: ["AudioBridge"],
            path: "Sources/SDK/AVFoundation"
        ),
        .target(
            name: "UniformTypeIdentifiers",
            path: "Sources/SDK/UniformTypeIdentifiers"
        ),
        .target(
            name: "KeychainServices",
            dependencies: ["PosixShim"],
            path: "Sources/SDK/KeychainServices"
        ),

        // ── Apps ─────────────────────────────────────────────────
        .executableTarget(
            name: "CloneDesktop",
            dependencies: ["SwiftUI", "EngineBridge", "CloneServer"],
            path: "Sources/Apps/Compositor",
            linkerSettings: [
                .unsafeFlags([
                    "-L", "/Users/manz/Projects/clone/target/debug",
                    "-lclone_engine",
                    "-Xlinker", "-rpath", "-Xlinker", "/Users/manz/Projects/clone/target/debug",
                ]),
            ]
        ),
        .executableTarget(
            name: "Finder",
            dependencies: ["SwiftUI"],
            path: "Sources/Apps/Finder",
            exclude: ["Info.plist"],
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "Settings",
            dependencies: ["SwiftUI"],
            path: "Sources/Apps/Settings"
        ),
        .executableTarget(
            name: "Dock",
            dependencies: ["SwiftUI"],
            path: "Sources/Apps/Dock"
        ),
        .executableTarget(
            name: "MenuBar",
            dependencies: ["SwiftUI", "CloneProtocol", "CloneClient", "PosixShim"],
            path: "Sources/Apps/MenuBar"
        ),
        .executableTarget(
            name: "Password",
            dependencies: ["SwiftUI"],
            path: "Sources/Apps/Password"
        ),
        .executableTarget(
            name: "TextEdit",
            dependencies: ["SwiftUI", "CloneProtocol"],
            path: "Sources/Apps/TextEdit",
            exclude: ["Info.plist"]
        ),
        .executableTarget(
            name: "Preview",
            dependencies: ["SwiftUI", "CloneProtocol"],
            path: "Sources/Apps/Preview",
            exclude: ["Info.plist"]
        ),
        .executableTarget(
            name: "LoginWindow",
            dependencies: ["SwiftUI"],
            path: "Sources/Apps/LoginWindow"
        ),

        // ── Daemons ──────────────────────────────────────────────
        .target(
            name: "CloneDaemon",
            dependencies: ["CloneProtocol", "PosixShim"],
            path: "Sources/Daemons/CloneDaemon"
        ),
        .executableTarget(
            name: "cloned",
            dependencies: ["CloneDaemon", "CloneProtocol"],
            path: "Sources/Daemons/cloned"
        ),
        .target(
            name: "CloneKeychain",
            dependencies: ["CSQLite", "CloneProtocol", "PosixShim"],
            path: "Sources/Daemons/CloneKeychain"
        ),
        .executableTarget(
            name: "keychaind",
            dependencies: ["CloneKeychain", "CloneProtocol"],
            path: "Sources/Daemons/keychaind"
        ),

        .target(
            name: "CloneLaunchServices",
            dependencies: ["CloneProtocol", "PosixShim"],
            path: "Sources/Daemons/CloneLaunchServices"
        ),
        .executableTarget(
            name: "launchservicesd",
            dependencies: ["CloneLaunchServices", "CloneProtocol", "AvocadoEvents"],
            path: "Sources/Daemons/launchservicesd"
        ),
        .target(
            name: "AvocadoEvents",
            dependencies: ["CloneProtocol", "PosixShim"],
            path: "Sources/Daemons/AvocadoEvents"
        ),
        .executableTarget(
            name: "avocadoeventsd",
            dependencies: ["AvocadoEvents", "CloneProtocol"],
            path: "Sources/Daemons/avocadoeventsd"
        ),

        // ── Tools ────────────────────────────────────────────────
        .executableTarget(
            name: "ycodebuild",
            path: "Sources/Tools/ycodebuild"
        ),
        .executableTarget(
            name: "open",
            dependencies: ["CloneProtocol", "CloneLaunchServices", "AvocadoEvents"],
            path: "Sources/Tools/open"
        ),

        // ── Tests ────────────────────────────────────────────────
        .testTarget(
            name: "QuartzCoreTests",
            dependencies: ["QuartzCore"],
            path: "Tests/QuartzCoreTests"
        ),
        .testTarget(
            name: "SharedSurfaceTests",
            dependencies: ["SharedSurface"],
            path: "Tests/SharedSurfaceTests"
        ),
        .testTarget(
            name: "SwiftUITests",
            dependencies: ["SwiftUI"],
            path: "Tests/SwiftUITests"
        ),
        .testTarget(
            name: "SwiftDataTests",
            dependencies: ["SwiftData"],
            path: "Tests/SwiftDataTests"
        ),
        .testTarget(
            name: "CloneDaemonTests",
            dependencies: ["CloneDaemon", "CloneProtocol"],
            path: "Tests/CloneDaemonTests"
        ),
        .testTarget(
            name: "AVFoundationTests",
            dependencies: ["AVFoundation"],
            path: "Tests/AVFoundationTests"
        ),
        .testTarget(
            name: "CloneKeychainTests",
            dependencies: ["CloneKeychain", "CloneProtocol"],
            path: "Tests/CloneKeychainTests"
        ),
        .testTarget(
            name: "SecurityTests",
            dependencies: ["KeychainServices"],
            path: "Tests/SecurityTests"
        ),
        .testTarget(
            name: "CloneLaunchServicesTests",
            dependencies: ["CloneLaunchServices", "CloneProtocol"],
            path: "Tests/CloneLaunchServicesTests"
        ),
    ]
)
