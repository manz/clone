import Testing
import Foundation
@testable import SwiftData

@Test func openInMemory() throws {
    let db = try SQLiteConnection(path: ":memory:")
    #expect(db.handle != nil)
    db.close()
}

@Test func createTableAndInsert() throws {
    let db = try SQLiteConnection(path: ":memory:")
    try db.execute("CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT NOT NULL)")
    try db.execute("INSERT INTO t (id, name) VALUES (?, ?)", parameters: [.integer(1), .text("hello")])
    let rows = try db.query("SELECT id, name FROM t")
    #expect(rows.count == 1)
    #expect(rows[0][0] == .integer(1))
    #expect(rows[0][1] == .text("hello"))
}

@Test func multipleInsertAndQuery() throws {
    let db = try SQLiteConnection(path: ":memory:")
    try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY, value REAL)")
    for i in 1...5 {
        try db.execute("INSERT INTO items (id, value) VALUES (?, ?)",
                       parameters: [.integer(Int64(i)), .real(Double(i) * 1.5)])
    }
    let rows = try db.query("SELECT * FROM items ORDER BY id")
    #expect(rows.count == 5)
    #expect(rows[2][1] == .real(4.5))
}

@Test func blobStorage() throws {
    let db = try SQLiteConnection(path: ":memory:")
    try db.execute("CREATE TABLE blobs (id INTEGER PRIMARY KEY, data BLOB)")
    let data = Data([0xDE, 0xAD, 0xBE, 0xEF])
    try db.execute("INSERT INTO blobs (id, data) VALUES (?, ?)", parameters: [.integer(1), .blob(data)])
    let rows = try db.query("SELECT data FROM blobs")
    #expect(rows[0][0] == .blob(data))
}

@Test func nullHandling() throws {
    let db = try SQLiteConnection(path: ":memory:")
    try db.execute("CREATE TABLE nullable (id INTEGER PRIMARY KEY, name TEXT)")
    try db.execute("INSERT INTO nullable (id, name) VALUES (?, ?)", parameters: [.integer(1), .null])
    let rows = try db.query("SELECT name FROM nullable")
    #expect(rows[0][0] == .null)
}

@Test func sqliteTransaction() throws {
    let db = try SQLiteConnection(path: ":memory:")
    try db.execute("CREATE TABLE t (id INTEGER PRIMARY KEY)")
    try db.transaction {
        try db.execute("INSERT INTO t (id) VALUES (?)", parameters: [.integer(1)])
        try db.execute("INSERT INTO t (id) VALUES (?)", parameters: [.integer(2)])
    }
    let rows = try db.query("SELECT COUNT(*) FROM t")
    #expect(rows[0][0] == .integer(2))
}

@Test func transactionRollback() throws {
    let db = try SQLiteConnection(path: ":memory:")
    try db.execute("CREATE TABLE t (id INTEGER PRIMARY KEY)")
    try db.execute("INSERT INTO t (id) VALUES (?)", parameters: [.integer(1)])

    struct TestError: Error {}
    do {
        try db.transaction {
            try db.execute("INSERT INTO t (id) VALUES (?)", parameters: [.integer(2)])
            throw TestError()
        }
    } catch is TestError {}

    let rows = try db.query("SELECT COUNT(*) FROM t")
    #expect(rows[0][0] == .integer(1))
}

@Test func lastInsertRowID() throws {
    let db = try SQLiteConnection(path: ":memory:")
    try db.execute("CREATE TABLE t (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)")
    try db.execute("INSERT INTO t (name) VALUES (?)", parameters: [.text("first")])
    #expect(db.lastInsertRowID == 1)
    try db.execute("INSERT INTO t (name) VALUES (?)", parameters: [.text("second")])
    #expect(db.lastInsertRowID == 2)
}

@Test func executeReturnsChangedRows() throws {
    let db = try SQLiteConnection(path: ":memory:")
    try db.execute("CREATE TABLE t (id INTEGER PRIMARY KEY, val INTEGER)")
    try db.execute("INSERT INTO t VALUES (1, 10)")
    try db.execute("INSERT INTO t VALUES (2, 20)")
    try db.execute("INSERT INTO t VALUES (3, 10)")
    let changed = try db.execute("DELETE FROM t WHERE val = ?", parameters: [.integer(10)])
    #expect(changed == 2)
}
