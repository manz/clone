// swift-tools-version: 6.2
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Clone",
    platforms: [.macOS(.v14)],
    products: [
        // Public SDK products — external apps depend on these
        // AppKit is exposed transitively via SwiftUI (not listed here to avoid
        // shadowing macOS's real AppKit in the dependency resolver)
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
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        .systemLibrary(
            name: "clone_engineFFI",
            path: "Sources/CEngine"
        ),
        // Audio FFI C bridge
        .systemLibrary(
            name: "clone_audioFFI",
            path: "Sources/CAudio"
        ),
        // Audio UniFFI-generated Swift bindings
        .target(
            name: "AudioBridge",
            dependencies: ["clone_audioFFI"],
            path: "Sources/AudioBridge",
            linkerSettings: [
                .unsafeFlags([
                    "-L", "target/debug",
                    "-lclone_audio",
                    "-Xlinker", "-rpath", "-Xlinker", "target/debug",
                ]),
            ]
        ),
        // AVFoundation — real implementation backed by Rust audio engine
        .target(
            name: "AVFoundation",
            dependencies: ["AudioBridge"],
            path: "Sources/AVFoundation"
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
            dependencies: ["AppKit", "CloneClient", "CloneProtocol", "SwiftDataMacros"],
            path: "Sources/SwiftUI",
            exclude: ["Generated"]
        ),
        // Stub modules — shadow Apple frameworks that Clone doesn't implement
        .target(
            name: "Charts",
            dependencies: ["SwiftUI"],
            path: "Sources/Charts"
        ),
        .target(
            name: "MediaPlayer",
            dependencies: ["CloneProtocol"],
            path: "Sources/MediaPlayer"
        ),
        .target(
            name: "AVKit",
            path: "Sources/AVKit"
        ),
        .target(
            name: "UniformTypeIdentifiers",
            path: "Sources/UniformTypeIdentifiers"
        ),
        // Now-playing daemon (library — testable)
        .target(
            name: "CloneDaemon",
            dependencies: ["CloneProtocol"],
            path: "Sources/CloneDaemon"
        ),
        // Now-playing daemon executable
        .executableTarget(
            name: "cloned",
            dependencies: ["CloneDaemon", "CloneProtocol"],
            path: "Sources/cloned"
        ),
        // Keychain daemon (library — testable)
        .target(
            name: "CloneKeychain",
            dependencies: ["CSQLite", "CloneProtocol"],
            path: "Sources/CloneKeychain"
        ),
        // Keychain daemon executable
        .executableTarget(
            name: "keychaind",
            dependencies: ["CloneKeychain", "CloneProtocol"],
            path: "Sources/keychaind"
        ),
        // Security framework shim (Keychain Services API)
        // Named KeychainServices on macOS to avoid circular dep with Foundation→Security.
        // On Linux this becomes the "Security" module since there's no system Security.
        .target(
            name: "KeychainServices",
            dependencies: [],
            path: "Sources/KeychainServices"
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
            dependencies: ["SwiftUI", "CloneProtocol", "CloneClient"],
            path: "Sources/MenuBarApp"
        ),
        // Password app (separate process)
        .executableTarget(
            name: "PasswordApp",
            dependencies: ["SwiftUI"],
            path: "Sources/PasswordApp"
        ),
        // TextEdit app (separate process)
        .executableTarget(
            name: "TextEditApp",
            dependencies: ["SwiftUI", "CloneProtocol"],
            path: "Sources/TextEditApp"
        ),
        // Preview app (separate process)
        .executableTarget(
            name: "PreviewApp",
            dependencies: ["SwiftUI", "CloneProtocol"],
            path: "Sources/PreviewApp"
        ),
        // Login window (separate process, pre-session)
        .executableTarget(
            name: "LoginWindow",
            dependencies: ["SwiftUI"],
            path: "Sources/LoginWindowApp"
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
        // SwiftData macro compiler plugin
        .macro(
            name: "SwiftDataMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            path: "Sources/SwiftDataMacros"
        ),
        .target(
            name: "SwiftData",
            dependencies: ["CSQLite", "SwiftDataMacros"],
            path: "Sources/SwiftData"
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
        // ycodebuild — CLI tool for building external apps against Aquax SDK
        .executableTarget(
            name: "ycodebuild",
            path: "Sources/ycodebuild"
        ),
    ]
)
