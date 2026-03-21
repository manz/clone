import Foundation

/// Configuration for where and how to store model data.
public struct ModelConfiguration {
    public let appId: String?
    public let url: URL?
    public let isStoredInMemoryOnly: Bool

    /// Standard configuration for an app. DB at ~/Library/Application Support/{appId}/data.sqlite.
    public init(appId: String) {
        self.appId = appId
        self.url = nil
        self.isStoredInMemoryOnly = false
    }

    /// Explicit URL configuration.
    public init(url: URL) {
        self.appId = nil
        self.url = url
        self.isStoredInMemoryOnly = false
    }

    /// In-memory database (for tests).
    public init(isStoredInMemoryOnly: Bool) {
        self.appId = nil
        self.url = nil
        self.isStoredInMemoryOnly = isStoredInMemoryOnly
    }

    /// Named configuration with optional schema and URL — matches Apple's SwiftData API.
    public init(_ name: String, schema: Schema? = nil, url: URL? = nil, isStoredInMemoryOnly: Bool = false) {
        self.appId = name
        self.url = url
        self.isStoredInMemoryOnly = isStoredInMemoryOnly
    }

    /// Default configuration.
    public init() {
        self.appId = nil
        self.url = nil
        self.isStoredInMemoryOnly = false
    }

    /// Resolve the SQLite path.
    public func resolvedPath() -> String {
        if isStoredInMemoryOnly { return ":memory:" }
        if let url = url { return url.path }
        guard let appId = appId else { return ":memory:" }

        let appSupport = NSHomeDirectory() + "/Library/Application Support/\(appId)"
        try? FileManager.default.createDirectory(atPath: appSupport, withIntermediateDirectories: true)
        return appSupport + "/data.sqlite"
    }
}
