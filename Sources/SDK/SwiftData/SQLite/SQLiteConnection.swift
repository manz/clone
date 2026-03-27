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
/// All access is serialized through a recursive lock for thread safety.
public final class SQLiteConnection {
    private(set) var handle: OpaquePointer?
    private let lock = NSRecursiveLock()

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
        lock.lock()
        defer { lock.unlock() }
        let stmt = try SQLiteStatement(db: handle!, sql: sql)
        if !parameters.isEmpty {
            try stmt.bind(parameters)
        }
        try stmt.execute()
        return Int(sqlite3_changes(handle))
    }

    /// Query SQL that returns rows.
    public func query(_ sql: String, parameters: [SQLiteValue] = []) throws -> [[SQLiteValue]] {
        lock.lock()
        defer { lock.unlock() }
        let stmt = try SQLiteStatement(db: handle!, sql: sql)
        if !parameters.isEmpty {
            try stmt.bind(parameters)
        }
        return try stmt.query()
    }

    /// Prepare a statement for repeated use.
    public func prepare(_ sql: String) throws -> SQLiteStatement {
        lock.lock()
        defer { lock.unlock() }
        return try SQLiteStatement(db: handle!, sql: sql)
    }

    /// Last insert rowid.
    public var lastInsertRowID: Int64 {
        lock.lock()
        defer { lock.unlock() }
        return sqlite3_last_insert_rowid(handle)
    }

    // MARK: - Transaction

    /// Run a block inside a SQLite transaction.
    /// The body can safely call execute/query (recursive lock).
    public func transaction(_ body: () throws -> Void) throws {
        lock.lock()
        defer { lock.unlock() }
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
        lock.lock()
        defer { lock.unlock() }
        if let h = handle {
            sqlite3_close(h)
            handle = nil
        }
    }
}
