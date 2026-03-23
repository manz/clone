import Foundation

struct YCodeBuild {
    let sdkPath: String
    let target: String
    let sourceDir: String

    func run() throws {
        let sourceDirURL = URL(fileURLWithPath: sourceDir)
        let parentDir = sourceDirURL.deletingLastPathComponent()
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
        let relativeSourceDir = sourceDirURL.lastPathComponent
        let packageDir = sourceDirURL.deletingLastPathComponent()
        try PackageGenerator.generate(
            target: target,
            sdkPath: sdkPath,
            sourceDir: relativeSourceDir,
            stubs: sdkStubs,
            sdkModules: classified.sdk,
            outputDir: packageDir.path,
            aquaxDir: aquaxDir.path
        )

        print("ycodebuild: generated .aquax/Package.swift and stub modules")
        print("ycodebuild: building \(target)...")

        // Run swift build
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["build", "--package-path", parentDir.path, "--target", target]
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
        sourceDir: resolvedSource
    )
}

func printUsage() {
    print("""
    USAGE: ycodebuild [--sdk-path <path>] [--target <name>] [--source-dir <path>]

    OPTIONS:
      --sdk-path    Path to Clone SDK repo (default: $AQUAX_SDK_PATH or ~/Projects/clone)
      --target      Executable target name (default: source directory name)
      --source-dir  Path to app source files (default: .)
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
