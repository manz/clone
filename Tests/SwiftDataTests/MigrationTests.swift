import Testing
import Foundation
@testable import SwiftData

@Test func autoMigrateAddsColumn() throws {
    let db = try SQLiteConnection(path: ":memory:")
    try db.execute("CREATE TABLE Bookmark (id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL)")

    let migrator = SchemaMigrator(connection: db)
    let schema = ModelSchema(name: "Bookmark", properties: [
        PropertySchema(name: "name", type: .string),
        PropertySchema(name: "path", type: .string),
        PropertySchema(name: "pinned", type: .bool),
    ])
    try migrator.autoMigrate(schemas: [schema])

    try db.execute("INSERT INTO Bookmark (id, name, path, pinned) VALUES (?, ?, ?, ?)",
                   parameters: [.text("abc"), .text("Test"), .text("/test"), .integer(1)])
    let rows = try db.query("SELECT path, pinned FROM Bookmark")
    #expect(rows[0][0] == .text("/test"))
    #expect(rows[0][1] == .integer(1))
}

@Test func autoMigrateCreatesNewTable() throws {
    let db = try SQLiteConnection(path: ":memory:")
    let migrator = SchemaMigrator(connection: db)
    let schema = ModelSchema(name: "NewTable", properties: [
        PropertySchema(name: "value", type: .string),
    ])
    try migrator.autoMigrate(schemas: [schema])

    try db.execute("INSERT INTO NewTable (id, value) VALUES (?, ?)",
                   parameters: [.text("1"), .text("hello")])
    let rows = try db.query("SELECT value FROM NewTable")
    #expect(rows[0][0] == .text("hello"))
}

@Test func versionTracking() throws {
    let db = try SQLiteConnection(path: ":memory:")
    let migrator = SchemaMigrator(connection: db)

    let v0 = try migrator.currentVersion()
    #expect(v0 == 0)

    try migrator.setVersion(3)
    let v3 = try migrator.currentVersion()
    #expect(v3 == 3)
}

@Test func migrationPlan() throws {
    let db = try SQLiteConnection(path: ":memory:")
    try db.execute("CREATE TABLE items (id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL)")

    let migrator = SchemaMigrator(connection: db)
    try migrator.ensureMetaTable()
    try migrator.setVersion(0)

    let plan = SchemaMigrationPlan(stages: [
        MigrationStage(from: 0, to: 1, operations: [
            .addColumn(table: "items", column: PropertySchema(name: "description", type: .string)),
        ]),
        MigrationStage(from: 1, to: 2, operations: [
            .addColumn(table: "items", column: PropertySchema(name: "count", type: .int)),
        ]),
    ])
    try migrator.migrate(plan: plan)

    let version = try migrator.currentVersion()
    #expect(version == 2)

    try db.execute("INSERT INTO items (id, name, description, count) VALUES (?, ?, ?, ?)",
                   parameters: [.text("1"), .text("test"), .text("desc"), .integer(42)])
    let rows = try db.query("SELECT description, count FROM items")
    #expect(rows[0][0] == .text("desc"))
    #expect(rows[0][1] == .integer(42))
}

@Test func migrationSkipsAlreadyAppliedStages() throws {
    let db = try SQLiteConnection(path: ":memory:")
    try db.execute("CREATE TABLE items (id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL, description TEXT)")

    let migrator = SchemaMigrator(connection: db)
    try migrator.ensureMetaTable()
    try migrator.setVersion(1)

    let plan = SchemaMigrationPlan(stages: [
        MigrationStage(from: 0, to: 1, operations: [
            .addColumn(table: "items", column: PropertySchema(name: "description", type: .string)),
        ]),
        MigrationStage(from: 1, to: 2, operations: [
            .addColumn(table: "items", column: PropertySchema(name: "priority", type: .int)),
        ]),
    ])
    try migrator.migrate(plan: plan)

    let version = try migrator.currentVersion()
    #expect(version == 2)
}

@Test func renameColumnMigration() throws {
    let db = try SQLiteConnection(path: ":memory:")
    try db.execute("CREATE TABLE items (id TEXT PRIMARY KEY NOT NULL, old_name TEXT NOT NULL)")
    try db.execute("INSERT INTO items (id, old_name) VALUES ('1', 'hello')")

    let migrator = SchemaMigrator(connection: db)
    try migrator.ensureMetaTable()

    let plan = SchemaMigrationPlan(stages: [
        MigrationStage(from: 0, to: 1, operations: [
            .renameColumn(table: "items", from: "old_name", to: "new_name"),
        ]),
    ])
    try migrator.migrate(plan: plan)

    let rows = try db.query("SELECT new_name FROM items")
    #expect(rows[0][0] == .text("hello"))
}
