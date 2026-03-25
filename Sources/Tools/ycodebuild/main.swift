import Foundation

struct YCodeBuild {
    let sdkPath: String
    let target: String
    let sourceDir: String
    let prebuilt: Bool
    let outputDir: String?
    let bundle: Bool

    func run() throws {
        let sourceDirURL = URL(fileURLWithPath: sourceDir)
        let parentDir: URL
        if let outputDir {
            parentDir = URL(fileURLWithPath: outputDir)
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        } else {
            parentDir = sourceDirURL.deletingLastPathComponent()
        }
        let aquaxDir = parentDir.appendingPathComponent(".aquax")

        print("ycodebuild: scanning \(sourceDir) for imports...")
        let imports = try ImportScanner.scan(directory: sourceDir)
        print("ycodebuild: found \(imports.count) unique imports: \(imports.sorted().joined(separator: ", "))")

        // Remove the target's own module name from imports (self-import)
        var filteredImports = imports
        filteredImports.remove(target)

        let sdkManifest = try SDKManifest.load(from: sdkPath)
        let classified = sdkManifest.classify(imports: filteredImports)

        print("ycodebuild: SDK-provided: \(classified.sdk.sorted().joined(separator: ", "))")
        print("ycodebuild: system (pass-through): \(classified.system.sorted().joined(separator: ", "))")
        print("ycodebuild: needs stub: \(classified.stubs.sorted().joined(separator: ", "))")
        if !classified.unknown.isEmpty {
            print("ycodebuild: unknown (will attempt stub): \(classified.unknown.sorted().joined(separator: ", "))")
        }

        // Clean stale stubs from previous runs
        let stubsDir = aquaxDir.appendingPathComponent("stubs")
        if FileManager.default.fileExists(atPath: stubsDir.path) {
            try FileManager.default.removeItem(at: stubsDir)
        }

        // SDK stubs are now proper targets in Clone — only generate stubs for truly unknown modules
        let unknownStubs = classified.unknown
        if !unknownStubs.isEmpty {
            try StubGenerator.generate(modules: unknownStubs, outputDir: stubsDir.path)
        }

        // SDK-provided stubs (Charts, MediaPlayer, etc.) are referenced as Clone products
        let sdkStubs = classified.stubs

        // Generate Package.swift
        // SPM doesn't allow paths outside the package root. When --output-dir is set,
        // create a symlink inside the package dir pointing to the real source.
        let sourcePathForPackage: String
        if outputDir != nil {
            let linkName = sourceDirURL.lastPathComponent
            let linkURL = parentDir.appendingPathComponent(linkName)
            let fm = FileManager.default
            // Remove stale symlink
            if fm.fileExists(atPath: linkURL.path) {
                try fm.removeItem(at: linkURL)
            }
            try fm.createSymbolicLink(at: linkURL, withDestinationURL: sourceDirURL.standardizedFileURL)
            sourcePathForPackage = linkName
        } else {
            sourcePathForPackage = sourceDirURL.lastPathComponent
        }

        if prebuilt {
            try PackageGenerator.generatePrebuilt(
                target: target,
                sdkPath: sdkPath,
                sourceDir: sourcePathForPackage,
                outputDir: parentDir.path,
                aquaxDir: aquaxDir.path
            )
        } else {
            try PackageGenerator.generate(
                target: target,
                sdkPath: sdkPath,
                sourceDir: sourcePathForPackage,
                stubs: sdkStubs,
                sdkModules: classified.sdk,
                outputDir: parentDir.path,
                aquaxDir: aquaxDir.path
            )
        }

        print("ycodebuild: generated .aquax/Package.swift and stub modules")

        // Detect mode switch and clean stale build cache to avoid phantom modules.
        // A prior source-dep build leaves .swiftmodule files (e.g. Sparkle) that make
        // canImport() return true even when the module isn't in the new Package.swift.
        let modeMarker = aquaxDir.appendingPathComponent(".build-mode")
        let currentMode = prebuilt ? "prebuilt" : "source"
        let previousMode = try? String(contentsOf: modeMarker, encoding: .utf8)
        if previousMode != nil && previousMode != currentMode {
            print("ycodebuild: build mode changed (\(previousMode!) → \(currentMode)), cleaning build cache...")
            let cleanProcess = Process()
            cleanProcess.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
            cleanProcess.arguments = ["package", "--package-path", parentDir.path, "clean"]
            cleanProcess.standardOutput = FileHandle.nullDevice
            cleanProcess.standardError = FileHandle.nullDevice
            try cleanProcess.run()
            cleanProcess.waitUntilExit()
        }
        try currentMode.write(to: modeMarker, atomically: true, encoding: .utf8)

        print("ycodebuild: building \(target)...")

        // Run swift build
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["build", "--package-path", parentDir.path, "--product", target]
        process.currentDirectoryURL = parentDir

        // Stream build output directly to terminal
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            print("ycodebuild: build succeeded!")
            // Use swift build --show-bin-path to get the actual binary location
            let binPathProcess = Process()
            binPathProcess.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
            binPathProcess.arguments = ["build", "--package-path", parentDir.path, "--show-bin-path"]
            let pipe = Pipe()
            binPathProcess.standardOutput = pipe
            binPathProcess.standardError = FileHandle.nullDevice
            try binPathProcess.run()
            binPathProcess.waitUntilExit()
            let binDir = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? parentDir.appendingPathComponent(".build/debug").path
            let binaryPath = "\(binDir)/\(target)"
            print("ycodebuild: binary at \(binaryPath)")

            if bundle {
                let bundlePath = try assembleBundle(
                    target: target,
                    binaryPath: binaryPath,
                    sourceDir: sourceDir,
                    outputDir: parentDir.path
                )
                print("ycodebuild: bundle at \(bundlePath)")
            }
        } else {
            print("ycodebuild: build failed with exit code \(process.terminationStatus)")
            throw YCodeBuildError.buildFailed(Int(process.terminationStatus))
        }
    }
}

enum YCodeBuildError: Error {
    case buildFailed(Int)
    case missingArgument(String)
}

// MARK: - Bundle Assembly

func assembleBundle(target: String, binaryPath: String, sourceDir: String, outputDir: String) throws -> String {
    let fm = FileManager.default
    let appDir = "\(outputDir)/\(target).app"
    let contentsDir = "\(appDir)/Contents"
    let macosDir = "\(contentsDir)/MacOS"
    let resourcesDir = "\(contentsDir)/Resources"

    // Create directory structure
    try fm.createDirectory(atPath: macosDir, withIntermediateDirectories: true)
    try fm.createDirectory(atPath: resourcesDir, withIntermediateDirectories: true)

    // Copy binary
    let destBinary = "\(macosDir)/\(target)"
    if fm.fileExists(atPath: destBinary) { try fm.removeItem(atPath: destBinary) }
    try fm.copyItem(atPath: binaryPath, toPath: destBinary)

    // Info.plist: use source dir's if present, otherwise generate default
    let plistDest = "\(contentsDir)/Info.plist"
    let sourcePlist = "\(sourceDir)/Info.plist"
    if fm.fileExists(atPath: sourcePlist) {
        // Merge: load source plist, fill in missing defaults
        let sourceData = try Data(contentsOf: URL(fileURLWithPath: sourcePlist))
        var plist = try PropertyListSerialization.propertyList(from: sourceData, format: nil) as? [String: Any] ?? [:]
        let defaults = generateInfoPlist(target: target)
        for (key, value) in defaults where plist[key] == nil {
            plist[key] = value
        }
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: URL(fileURLWithPath: plistDest))
        print("ycodebuild: merged Info.plist from \(sourcePlist)")
    } else {
        // Generate default
        let plist = generateInfoPlist(target: target)
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: URL(fileURLWithPath: plistDest))
        print("ycodebuild: generated default Info.plist")
    }

    // Copy Resources (icons, lproj dirs) if they exist
    let sourceResources = "\(sourceDir)/Resources"
    if fm.fileExists(atPath: sourceResources) {
        let items = try fm.contentsOfDirectory(atPath: sourceResources)
        for item in items {
            let src = "\(sourceResources)/\(item)"
            let dest = "\(resourcesDir)/\(item)"
            if fm.fileExists(atPath: dest) { try fm.removeItem(atPath: dest) }
            try fm.copyItem(atPath: src, toPath: dest)
        }
        print("ycodebuild: copied \(items.count) resource(s)")
    }

    return appDir
}

func generateInfoPlist(target: String) -> [String: Any] {
    [
        "CFBundleIdentifier": "com.clone.\(target.lowercased())",
        "CFBundleName": target,
        "CFBundleDisplayName": target,
        "CFBundleExecutable": target,
        "CFBundlePackageType": "APPL",
        "CFBundleVersion": "1",
        "CFBundleShortVersionString": "0.1.0",
    ]
}

// MARK: - SDK Manifest

struct SDKManifest: Codable {
    let version: String
    let modules: [String: ModuleInfo]
    let system: [String]
    let stubs: [String]

    struct ModuleInfo: Codable {
        let status: String
    }

    struct ClassifiedImports {
        let sdk: Set<String>
        let system: Set<String>
        let stubs: Set<String>
        let unknown: Set<String>
    }

    static func load(from sdkPath: String) throws -> SDKManifest {
        let url = URL(fileURLWithPath: sdkPath).appendingPathComponent("aquax-sdk.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SDKManifest.self, from: data)
    }

    func classify(imports: Set<String>) -> ClassifiedImports {
        var sdk = Set<String>()
        var system = Set<String>()
        var stubs = Set<String>()
        var unknown = Set<String>()

        let systemSet = Set(self.system)
        let stubSet = Set(self.stubs)

        for imp in imports {
            if modules[imp] != nil {
                sdk.insert(imp)
            } else if systemSet.contains(imp) {
                system.insert(imp)
            } else if stubSet.contains(imp) {
                stubs.insert(imp)
            } else {
                unknown.insert(imp)
            }
        }

        return ClassifiedImports(sdk: sdk, system: system, stubs: stubs, unknown: unknown)
    }
}

// MARK: - Argument Parsing

func parseArguments() throws -> YCodeBuild {
    let args = CommandLine.arguments
    var sdkPath: String?
    var target: String?
    var sourceDir: String?
    var prebuilt = false
    var bundle = false
    var outputDir: String?

    var i = 1
    while i < args.count {
        switch args[i] {
        case "--sdk-path":
            i += 1
            guard i < args.count else { throw YCodeBuildError.missingArgument("--sdk-path") }
            sdkPath = args[i]
        case "--target":
            i += 1
            guard i < args.count else { throw YCodeBuildError.missingArgument("--target") }
            target = args[i]
        case "--source-dir":
            i += 1
            guard i < args.count else { throw YCodeBuildError.missingArgument("--source-dir") }
            sourceDir = args[i]
        case "--output-dir":
            i += 1
            guard i < args.count else { throw YCodeBuildError.missingArgument("--output-dir") }
            outputDir = args[i]
        case "--prebuilt":
            prebuilt = true
        case "--bundle":
            bundle = true
        case "--help", "-h":
            printUsage()
            exit(0)
        default:
            // Positional: treat as source-dir
            if sourceDir == nil {
                sourceDir = args[i]
            }
        }
        i += 1
    }

    let resolvedSDK = sdkPath
        ?? ProcessInfo.processInfo.environment["AQUAX_SDK_PATH"]
        ?? (NSString(string: "~/Projects/clone").expandingTildeInPath)
    let resolvedSource = sourceDir ?? "."
    let resolvedTarget = target ?? URL(fileURLWithPath: resolvedSource).lastPathComponent

    return YCodeBuild(
        sdkPath: resolvedSDK,
        target: resolvedTarget,
        sourceDir: resolvedSource,
        prebuilt: prebuilt,
        outputDir: outputDir,
        bundle: bundle
    )
}

func printUsage() {
    print("""
    USAGE: ycodebuild [--sdk-path <path>] [--target <name>] [--source-dir <path>] [--output-dir <path>] [--prebuilt] [--bundle]

    OPTIONS:
      --sdk-path    Path to Clone SDK repo (default: $AQUAX_SDK_PATH or ~/Projects/clone)
      --target      Executable target name (default: source directory name)
      --source-dir  Path to app source files (default: .)
      --output-dir  Directory for generated Package.swift and build output (default: source-dir/..)
      --prebuilt    Link against prebuilt .framework bundles instead of building from source
      --bundle      Assemble a .app bundle after build (Info.plist, Resources, etc.)
      -h, --help    Show this help message
    """)
}

// MARK: - Entry Point

do {
    let build = try parseArguments()
    try build.run()
} catch let error as YCodeBuildError {
    switch error {
    case .buildFailed(let code):
        exit(Int32(code))
    case .missingArgument(let arg):
        print("Error: missing value for \(arg)")
        printUsage()
        exit(1)
    }
} catch {
    print("Error: \(error)")
    exit(1)
}
