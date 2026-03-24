import Foundation
import CSQLite
import CloneProtocol

/// Protocol for keychain storage (enables testing with in-memory store).
public protocol KeychainStoreProtocol {
    func add(_ item: KeychainItem) -> KeychainErrorCode
    func search(_ query: KeychainSearchQuery) -> KeychainResponse
    func update(query: KeychainSearchQuery, attributes: KeychainItem) -> KeychainErrorCode
    func delete(_ query: KeychainSearchQuery) -> KeychainErrorCode
}

/// SQLite-backed keychain storage.
///
/// Table: keychain_items(id INTEGER PRIMARY KEY, item_class TEXT, service TEXT, account TEXT,
///   server TEXT, label TEXT, value_data BLOB, access_group TEXT, app_id TEXT,
///   creation_date REAL, modification_date REAL)
///
/// For MVP, value_data is stored as plain BLOB (encryption via swift-crypto deferred).
public final class KeychainStore: KeychainStoreProtocol {
    private var db: OpaquePointer?

    /// Pass ":memory:" for tests, or a file path for persistence.
    public init(path: String = {
        let base = ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"] ?? "/tmp"
        return "\(base)/clone-keychain.db"
    }()) {
        var db: OpaquePointer?
        guard sqlite3_open(path, &db) == SQLITE_OK else {
            fatalError("Failed to open keychain database at \(path)")
        }
        self.db = db
        createTable()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Schema

    private func createTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS keychain_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            item_class TEXT NOT NULL,
            service TEXT,
            account TEXT,
            server TEXT,
            label TEXT,
            value_data BLOB,
            access_group TEXT,
            app_id TEXT NOT NULL,
            creation_date REAL NOT NULL,
            modification_date REAL NOT NULL
        )
        """
        execute(sql)
    }

    // MARK: - CRUD

    public func add(_ item: KeychainItem) -> KeychainErrorCode {
        // Check for duplicates: same class + service + account
        if hasDuplicate(item) {
            return .duplicateItem
        }

        let sql = """
        INSERT INTO keychain_items
            (item_class, service, account, server, label, value_data,
             access_group, app_id, creation_date, modification_date)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return .param
        }
        defer { sqlite3_finalize(stmt) }

        bindText(stmt, index: 1, value: item.itemClass.rawValue)
        bindOptionalText(stmt, index: 2, value: item.service)
        bindOptionalText(stmt, index: 3, value: item.account)
        bindOptionalText(stmt, index: 4, value: item.server)
        bindOptionalText(stmt, index: 5, value: item.label)
        bindOptionalBlob(stmt, index: 6, value: item.valueData)
        bindOptionalText(stmt, index: 7, value: item.accessGroup)
        bindText(stmt, index: 8, value: item.appId)
        sqlite3_bind_double(stmt, 9, item.creationDate.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 10, item.modificationDate.timeIntervalSince1970)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            return .param
        }
        return .success
    }

    public func search(_ query: KeychainSearchQuery) -> KeychainResponse {
        var conditions: [String] = []
        var values: [String] = []

        if let itemClass = query.itemClass {
            conditions.append("item_class = ?")
            values.append(itemClass.rawValue)
        }
        if let service = query.service {
            conditions.append("service = ?")
            values.append(service)
        }
        if let account = query.account {
            conditions.append("account = ?")
            values.append(account)
        }
        if let server = query.server {
            conditions.append("server = ?")
            values.append(server)
        }

        var sql = "SELECT id, item_class, service, account, server, label, value_data, access_group, app_id, creation_date, modification_date FROM keychain_items"
        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        if query.matchLimit == .one {
            sql += " LIMIT 1"
        }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return .error(.param)
        }
        defer { sqlite3_finalize(stmt) }

        for (i, value) in values.enumerated() {
            bindText(stmt, index: Int32(i + 1), value: value)
        }

        var items: [KeychainItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let item = readRow(stmt, returnData: query.returnData)
            items.append(item)
        }

        if items.isEmpty {
            return .error(.itemNotFound)
        }
        if query.matchLimit == .one {
            return .item(items[0])
        }
        return .items(items)
    }

    public func update(query: KeychainSearchQuery, attributes: KeychainItem) -> KeychainErrorCode {
        // Build WHERE clause from query
        var conditions: [String] = []
        var whereValues: [String] = []

        if let itemClass = query.itemClass {
            conditions.append("item_class = ?")
            whereValues.append(itemClass.rawValue)
        }
        if let service = query.service {
            conditions.append("service = ?")
            whereValues.append(service)
        }
        if let account = query.account {
            conditions.append("account = ?")
            whereValues.append(account)
        }
        if let server = query.server {
            conditions.append("server = ?")
            whereValues.append(server)
        }

        if conditions.isEmpty {
            return .param
        }

        // Build SET clause from non-nil attributes
        var setClauses: [String] = []
        var setBindings: [(Int32, (OpaquePointer?) -> Void)] = []
        var paramIndex: Int32 = 1

        if let service = attributes.service {
            setClauses.append("service = ?")
            let idx = paramIndex
            let val = service
            setBindings.append((idx, { stmt in self.bindText(stmt, index: idx, value: val) }))
            paramIndex += 1
        }
        if let account = attributes.account {
            setClauses.append("account = ?")
            let idx = paramIndex
            let val = account
            setBindings.append((idx, { stmt in self.bindText(stmt, index: idx, value: val) }))
            paramIndex += 1
        }
        if let server = attributes.server {
            setClauses.append("server = ?")
            let idx = paramIndex
            let val = server
            setBindings.append((idx, { stmt in self.bindText(stmt, index: idx, value: val) }))
            paramIndex += 1
        }
        if let label = attributes.label {
            setClauses.append("label = ?")
            let idx = paramIndex
            let val = label
            setBindings.append((idx, { stmt in self.bindText(stmt, index: idx, value: val) }))
            paramIndex += 1
        }
        if let valueData = attributes.valueData {
            setClauses.append("value_data = ?")
            let idx = paramIndex
            let val = valueData
            setBindings.append((idx, { stmt in self.bindOptionalBlob(stmt, index: idx, value: val) }))
            paramIndex += 1
        }
        if let accessGroup = attributes.accessGroup {
            setClauses.append("access_group = ?")
            let idx = paramIndex
            let val = accessGroup
            setBindings.append((idx, { stmt in self.bindText(stmt, index: idx, value: val) }))
            paramIndex += 1
        }

        // Always update modification_date
        setClauses.append("modification_date = ?")
        let modIdx = paramIndex
        let modTime = attributes.modificationDate.timeIntervalSince1970
        setBindings.append((modIdx, { stmt in sqlite3_bind_double(stmt, modIdx, modTime) }))
        paramIndex += 1

        if setClauses.isEmpty {
            return .param
        }

        let sql = "UPDATE keychain_items SET " + setClauses.joined(separator: ", ") +
                  " WHERE " + conditions.joined(separator: " AND ")

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return .param
        }
        defer { sqlite3_finalize(stmt) }

        // Bind SET values
        for (_, binder) in setBindings {
            binder(stmt)
        }

        // Bind WHERE values
        for (i, value) in whereValues.enumerated() {
            bindText(stmt, index: paramIndex + Int32(i), value: value)
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            return .param
        }

        let changes = sqlite3_changes(db)
        return changes > 0 ? .success : .itemNotFound
    }

    public func delete(_ query: KeychainSearchQuery) -> KeychainErrorCode {
        var conditions: [String] = []
        var values: [String] = []

        if let itemClass = query.itemClass {
            conditions.append("item_class = ?")
            values.append(itemClass.rawValue)
        }
        if let service = query.service {
            conditions.append("service = ?")
            values.append(service)
        }
        if let account = query.account {
            conditions.append("account = ?")
            values.append(account)
        }
        if let server = query.server {
            conditions.append("server = ?")
            values.append(server)
        }

        if conditions.isEmpty {
            return .param
        }

        let sql = "DELETE FROM keychain_items WHERE " + conditions.joined(separator: " AND ")

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return .param
        }
        defer { sqlite3_finalize(stmt) }

        for (i, value) in values.enumerated() {
            bindText(stmt, index: Int32(i + 1), value: value)
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            return .param
        }

        let changes = sqlite3_changes(db)
        return changes > 0 ? .success : .itemNotFound
    }

    // MARK: - Helpers

    private func hasDuplicate(_ item: KeychainItem) -> Bool {
        var conditions = ["item_class = ?"]
        var values = [item.itemClass.rawValue]

        if let service = item.service {
            conditions.append("service = ?")
            values.append(service)
        } else {
            conditions.append("service IS NULL")
        }

        if let account = item.account {
            conditions.append("account = ?")
            values.append(account)
        } else {
            conditions.append("account IS NULL")
        }

        let sql = "SELECT COUNT(*) FROM keychain_items WHERE " + conditions.joined(separator: " AND ")

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }

        for (i, value) in values.enumerated() {
            bindText(stmt, index: Int32(i + 1), value: value)
        }

        guard sqlite3_step(stmt) == SQLITE_ROW else { return false }
        return sqlite3_column_int(stmt, 0) > 0
    }

    private func readRow(_ stmt: OpaquePointer?, returnData: Bool) -> KeychainItem {
        let classStr = String(cString: sqlite3_column_text(stmt, 1))
        let itemClass = SecItemClass(rawValue: classStr) ?? .genericPassword

        let service = columnOptionalText(stmt, index: 2)
        let account = columnOptionalText(stmt, index: 3)
        let server = columnOptionalText(stmt, index: 4)
        let label = columnOptionalText(stmt, index: 5)

        var valueData: Data?
        if returnData {
            let blobSize = Int(sqlite3_column_bytes(stmt, 6))
            if blobSize > 0, let ptr = sqlite3_column_blob(stmt, 6) {
                valueData = Data(bytes: ptr, count: blobSize)
            }
        }

        let accessGroup = columnOptionalText(stmt, index: 7)
        let appId = String(cString: sqlite3_column_text(stmt, 8))
        let creationDate = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 9))
        let modificationDate = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 10))

        return KeychainItem(
            itemClass: itemClass,
            service: service,
            account: account,
            server: server,
            label: label,
            valueData: valueData,
            accessGroup: accessGroup,
            appId: appId,
            creationDate: creationDate,
            modificationDate: modificationDate
        )
    }

    private func columnOptionalText(_ stmt: OpaquePointer?, index: Int32) -> String? {
        if sqlite3_column_type(stmt, index) == SQLITE_NULL { return nil }
        return String(cString: sqlite3_column_text(stmt, index))
    }

    @discardableResult
    private func execute(_ sql: String) -> Bool {
        sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }

    @discardableResult
    private func bindText(_ stmt: OpaquePointer?, index: Int32, value: String) -> Int32 {
        value.withCString { ptr in
            sqlite3_bind_text(stmt, index, ptr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
    }

    @discardableResult
    private func bindOptionalText(_ stmt: OpaquePointer?, index: Int32, value: String?) -> Int32 {
        guard let value else { return sqlite3_bind_null(stmt, index) }
        return bindText(stmt, index: index, value: value)
    }

    @discardableResult
    private func bindOptionalBlob(_ stmt: OpaquePointer?, index: Int32, value: Data?) -> Int32 {
        guard let value else { return sqlite3_bind_null(stmt, index) }
        return value.withUnsafeBytes { ptr in
            sqlite3_bind_blob(stmt, index, ptr.baseAddress, Int32(value.count),
                              unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
    }
}
