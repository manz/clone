import Foundation
import CSQLite

/// Errors from the SQLite layer.
public enum SQLiteError: Error, Equatable {
    case open(String)
    case prepare(String)
    case bind(String)
    case step(String)
    case execute(String)
}

/// A connection to a SQLite database.
public final class SQLiteConnection {
    private(set) var handle: OpaquePointer?

    /// Open a database at `path`. Use ":memory:" for an in-memory database.
    public init(path: String) throws {
        let rc = sqlite3_open(path, &handle)
        guard rc == SQLITE_OK else {
            let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            sqlite3_close(handle)
            handle = nil
            throw SQLiteError.open(msg)
        }
        // Enable WAL mode for better concurrency.
        try execute("PRAGMA journal_mode=WAL")
        // Enable foreign keys.
        try execute("PRAGMA foreign_keys=ON")
    }

    deinit {
        close()
    }

    // MARK: - Execute

    /// Execute SQL that doesn't return rows.
    @discardableResult
    public func execute(_ sql: String, parameters: [SQLiteValue] = []) throws -> Int {
        let stmt = try SQLiteStatement(db: handle!, sql: sql)
        if !parameters.isEmpty {
            try stmt.bind(parameters)
        }
        try stmt.execute()
        return Int(sqlite3_changes(handle))
    }

    /// Query SQL that returns rows.
    public func query(_ sql: String, parameters: [SQLiteValue] = []) throws -> [[SQLiteValue]] {
        let stmt = try SQLiteStatement(db: handle!, sql: sql)
        if !parameters.isEmpty {
            try stmt.bind(parameters)
        }
        return try stmt.query()
    }

    /// Prepare a statement for repeated use.
    public func prepare(_ sql: String) throws -> SQLiteStatement {
        try SQLiteStatement(db: handle!, sql: sql)
    }

    /// Last insert rowid.
    public var lastInsertRowID: Int64 {
        sqlite3_last_insert_rowid(handle)
    }

    // MARK: - Transaction

    public func transaction(_ body: () throws -> Void) throws {
        try execute("BEGIN TRANSACTION")
        do {
            try body()
            try execute("COMMIT")
        } catch {
            try execute("ROLLBACK")
            throw error
        }
    }

    // MARK: - Close

    public func close() {
        if let h = handle {
            sqlite3_close(h)
            handle = nil
        }
    }
}
