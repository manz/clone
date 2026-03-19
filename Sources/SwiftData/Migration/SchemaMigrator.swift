import Foundation

/// Manages schema versioning and migration.
public final class SchemaMigrator {
    private let connection: SQLiteConnection
    private static let metaTable = "_clone_data_meta"

    public init(connection: SQLiteConnection) {
        self.connection = connection
    }

    /// Ensure the meta table exists.
    public func ensureMetaTable() throws {
        try connection.execute("""
            CREATE TABLE IF NOT EXISTS \(Self.metaTable) (
                key TEXT PRIMARY KEY NOT NULL,
                value TEXT NOT NULL
            )
        """)
    }

    /// Get the current schema version, or 0 if unset.
    public func currentVersion() throws -> Int {
        try ensureMetaTable()
        let rows = try connection.query(
            "SELECT value FROM \(Self.metaTable) WHERE key = ?",
            parameters: [.text("schema_version")]
        )
        guard let row = rows.first, case .text(let v) = row[0], let version = Int(v) else {
            return 0
        }
        return version
    }

    /// Set the schema version.
    public func setVersion(_ version: Int) throws {
        try connection.execute(
            "INSERT OR REPLACE INTO \(Self.metaTable) (key, value) VALUES (?, ?)",
            parameters: [.text("schema_version"), .text(String(version))]
        )
    }

    /// Auto-migrate by comparing current DB columns against schemas.
    /// Only supports adding missing columns (safe, non-destructive).
    public func autoMigrate(schemas: [ModelSchema]) throws {
        for schema in schemas {
            let existingColumns = try getColumns(for: schema.name)
            if existingColumns.isEmpty {
                // Table doesn't exist yet — create it.
                try connection.execute(schema.createTableSQL())
                continue
            }
            for prop in schema.properties where !existingColumns.contains(prop.name) {
                try addColumn(table: schema.name, property: prop)
            }
        }
    }

    /// Apply a migration plan from currentVersion to the latest stage.
    public func migrate(plan: SchemaMigrationPlan) throws {
        let current = try currentVersion()
        let applicable = plan.stages.filter { $0.fromVersion >= current }

        for stage in applicable {
            try connection.transaction {
                for op in stage.operations {
                    try applyOperation(op)
                }
            }
            try setVersion(stage.toVersion)
        }
    }

    // MARK: - Private

    private func getColumns(for table: String) throws -> Set<String> {
        let rows = try connection.query("PRAGMA table_info(\(table))")
        var columns: Set<String> = []
        for row in rows {
            if case .text(let name) = row[1] {
                columns.insert(name)
            }
        }
        return columns
    }

    private func addColumn(table: String, property: PropertySchema) throws {
        var sql = "ALTER TABLE \(table) ADD COLUMN \(property.name) \(property.sqlType)"
        if let def = property.defaultValue {
            sql += " DEFAULT \(def)"
        }
        try connection.execute(sql)
    }

    private func applyOperation(_ op: MigrationOperation) throws {
        switch op {
        case .addColumn(let table, let column):
            try addColumn(table: table, property: column)
        case .renameColumn(let table, let from, let to):
            try connection.execute("ALTER TABLE \(table) RENAME COLUMN \(from) TO \(to)")
        case .createTable(let schema):
            try connection.execute(schema.createTableSQL())
        case .dropTable(let name):
            try connection.execute("DROP TABLE IF EXISTS \(name)")
        case .custom(let sql):
            try connection.execute(sql)
        }
    }
}
