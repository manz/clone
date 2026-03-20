import Foundation

enum ImportScanner {
    /// Scan all .swift files in a directory tree and return unique import module names.
    static func scan(directory: String) throws -> Set<String> {
        let fm = FileManager.default
        let dirURL = URL(fileURLWithPath: directory)

        guard let enumerator = fm.enumerator(
            at: dirURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var imports = Set<String>()

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "swift" else { continue }

            // Skip platform-specific files that won't compile on macOS
            let filename = fileURL.lastPathComponent
            if filename.contains("+iOS") || filename.contains("+tvOS") ||
               filename.contains("+watchOS") || filename.contains("+visionOS") {
                continue
            }

            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let scanned = scanImports(in: content)
            imports.formUnion(scanned)
        }

        return imports
    }

    /// Extract import module names from Swift source code.
    static func scanImports(in source: String) -> Set<String> {
        var imports = Set<String>()

        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Match: import ModuleName
            // Match: import struct ModuleName.Type
            // Match: @testable import ModuleName
            if trimmed.hasPrefix("import ") || trimmed.hasPrefix("@testable import ") {
                let parts = trimmed.split(separator: " ")
                // Find the token after "import"
                if let importIdx = parts.firstIndex(of: "import"), importIdx + 1 < parts.count {
                    var moduleName = String(parts[importIdx + 1])
                    // Handle `import Module.Submodule` → take root module
                    if let dotIdx = moduleName.firstIndex(of: ".") {
                        moduleName = String(moduleName[..<dotIdx])
                    }
                    // Skip keywords like struct, class, enum, func after import
                    let keywords: Set<String> = ["struct", "class", "enum", "func", "protocol", "typealias"]
                    if keywords.contains(moduleName) {
                        // The actual module is the next token
                        if importIdx + 2 < parts.count {
                            moduleName = String(parts[importIdx + 2])
                            if let dotIdx = moduleName.firstIndex(of: ".") {
                                moduleName = String(moduleName[..<dotIdx])
                            }
                        }
                    }
                    imports.insert(moduleName)
                }
            }
        }

        return imports
    }
}
