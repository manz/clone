import Foundation

/// Creates a database and tables from model schemas. Manages the SQLite connection.
@objc(Clone_ModelContainer)
public final class ModelContainer: NSObject {
    public let connection: SQLiteConnection
    public let schemas: [ModelSchema]
    private let configuration: ModelConfiguration
    private var _mainContext: ModelContext?

    public init(for models: [any PersistentModel.Type], configuration: ModelConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)) throws {
        self.configuration = configuration
        self.schemas = models.map { $0.schema }
        self.connection = try SQLiteConnection(path: configuration.resolvedPath())
        super.init()
        try createTables()
    }

    /// Variadic convenience: `ModelContainer(for: Song.self, Artist.self)`
    public convenience init(for types: any PersistentModel.Type..., configurations: ModelConfiguration...) throws {
        let config = configurations.first ?? ModelConfiguration(isStoredInMemoryOnly: true)
        try self.init(for: Array(types), configuration: config)
    }

    /// Array configurations convenience: `ModelContainer(for: [...], configurations: [config])`
    public convenience init(for types: [any PersistentModel.Type], configurations: [ModelConfiguration]) throws {
        let config = configurations.first ?? ModelConfiguration(isStoredInMemoryOnly: true)
        try self.init(for: types, configuration: config)
    }

    /// Schema convenience: `ModelContainer(for: schema, configurations: config)`
    public convenience init(for schema: Schema, configurations: ModelConfiguration...) throws {
        let config = configurations.first ?? ModelConfiguration(isStoredInMemoryOnly: true)
        try self.init(for: schema.modelTypes, configuration: config)
    }

    /// The shared main context (property — matches Apple's SwiftData API).
    public var mainContext: ModelContext {
        if let ctx = _mainContext { return ctx }
        let ctx = ModelContext(container: self)
        _mainContext = ctx
        return ctx
    }

    /// Create a new independent context.
    public func newContext() -> ModelContext {
        ModelContext(container: self)
    }

    // MARK: - Private

    private func createTables() throws {
        for schema in schemas {
            try connection.execute(schema.createTableSQL())
        }
    }
}
