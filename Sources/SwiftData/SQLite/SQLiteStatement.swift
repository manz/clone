import Foundation
import CSQLite

/// Wraps a compiled sqlite3_stmt providing bind/step/column/finalize.
public final class SQLiteStatement {
    private var handle: OpaquePointer?
    private let db: OpaquePointer

    init(db: OpaquePointer, sql: String) throws {
        self.db = db
        let rc = sqlite3_prepare_v2(db, sql, -1, &handle, nil)
        guard rc == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw SQLiteError.prepare(msg)
        }
    }

    deinit {
        finalize()
    }

    // MARK: - Bind

    public func bind(_ values: [SQLiteValue]) throws {
        sqlite3_reset(handle)
        sqlite3_clear_bindings(handle)
        for (i, value) in values.enumerated() {
            let idx = Int32(i + 1)
            let rc: Int32
            switch value {
            case .null:
                rc = sqlite3_bind_null(handle, idx)
            case .integer(let v):
                rc = sqlite3_bind_int64(handle, idx, v)
            case .real(let v):
                rc = sqlite3_bind_double(handle, idx, v)
            case .text(let v):
                rc = sqlite3_bind_text(handle, idx, v, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case .blob(let v):
                rc = v.withUnsafeBytes { ptr in
                    sqlite3_bind_blob(handle, idx, ptr.baseAddress, Int32(v.count),
                                      unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                }
            }
            guard rc == SQLITE_OK else {
                throw SQLiteError.bind(String(cString: sqlite3_errmsg(db)))
            }
        }
    }

    // MARK: - Step

    /// Execute a statement that doesn't return rows (INSERT/UPDATE/DELETE/CREATE).
    /// Also handles PRAGMAs that return a result row.
    public func execute() throws {
        let rc = sqlite3_step(handle)
        if rc == SQLITE_ROW {
            // Drain remaining rows (e.g. PRAGMA journal_mode returns a row).
            while sqlite3_step(handle) == SQLITE_ROW {}
        } else if rc != SQLITE_DONE {
            throw SQLiteError.step(String(cString: sqlite3_errmsg(db)))
        }
        sqlite3_reset(handle)
    }

    /// Query rows. Returns an array of rows, each row being an array of SQLiteValue.
    public func query() throws -> [[SQLiteValue]] {
        var rows: [[SQLiteValue]] = []
        let colCount = sqlite3_column_count(handle)
        while true {
            let rc = sqlite3_step(handle)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else {
                throw SQLiteError.step(String(cString: sqlite3_errmsg(db)))
            }
            var row: [SQLiteValue] = []
            for col in 0..<colCount {
                row.append(columnValue(at: col))
            }
            rows.append(row)
        }
        sqlite3_reset(handle)
        return rows
    }

    // MARK: - Column

    private func columnValue(at index: Int32) -> SQLiteValue {
        let type = sqlite3_column_type(handle, index)
        switch type {
        case SQLITE_NULL:
            return .null
        case SQLITE_INTEGER:
            return .integer(sqlite3_column_int64(handle, index))
        case SQLITE_FLOAT:
            return .real(sqlite3_column_double(handle, index))
        case SQLITE_TEXT:
            let cstr = sqlite3_column_text(handle, index)!
            return .text(String(cString: cstr))
        case SQLITE_BLOB:
            let count = Int(sqlite3_column_bytes(handle, index))
            if count == 0 { return .blob(Data()) }
            let ptr = sqlite3_column_blob(handle, index)!
            return .blob(Data(bytes: ptr, count: count))
        default:
            return .null
        }
    }

    // MARK: - Finalize

    public func finalize() {
        if let h = handle {
            sqlite3_finalize(h)
            handle = nil
        }
    }
}
