// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Clone",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "DesktopKit",
            dependencies: [],
            path: "Sources/DesktopKit",
            exclude: ["Generated"]
        ),
        .executableTarget(
            name: "CloneDesktop",
            dependencies: ["DesktopKit"],
            path: "Sources/Apps"
        ),
        .testTarget(
            name: "DesktopKitTests",
            dependencies: ["DesktopKit"],
            path: "Tests/DesktopKitTests"
        ),
    ]
)
