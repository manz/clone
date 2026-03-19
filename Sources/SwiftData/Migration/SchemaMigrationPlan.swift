import Foundation

/// A single migration step.
public struct MigrationStage {
    public let fromVersion: Int
    public let toVersion: Int
    public let operations: [MigrationOperation]

    public init(from: Int, to: Int, operations: [MigrationOperation]) {
        self.fromVersion = from
        self.toVersion = to
        self.operations = operations
    }
}

/// Operations that can be performed in a migration.
public enum MigrationOperation {
    case addColumn(table: String, column: PropertySchema)
    case renameColumn(table: String, from: String, to: String)
    case createTable(schema: ModelSchema)
    case dropTable(name: String)
    case custom(sql: String)
}

/// A versioned migration plan with ordered stages.
public struct SchemaMigrationPlan {
    public let stages: [MigrationStage]

    public init(stages: [MigrationStage]) {
        self.stages = stages.sorted { $0.fromVersion < $1.fromVersion }
    }
}
