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
        .target(
            name: "DesktopKit",
            dependencies: [],
            path: "Sources/DesktopKit",
            exclude: ["Generated"]
        ),
        .target(
            name: "EngineBridge",
            dependencies: ["clone_engineFFI", "DesktopKit"],
            path: "Sources/EngineBridge"
        ),
        .executableTarget(
            name: "CloneDesktop",
            dependencies: ["DesktopKit", "EngineBridge"],
            path: "Sources/Apps",
            linkerSettings: [
                .unsafeFlags([
                    "-L", "target/debug",
                    "-lclone_engine",
                    "-Xlinker", "-rpath", "-Xlinker", "target/debug",
                ]),
            ]
        ),
        .testTarget(
            name: "DesktopKitTests",
            dependencies: ["DesktopKit"],
            path: "Tests/DesktopKitTests"
        ),
    ]
)
