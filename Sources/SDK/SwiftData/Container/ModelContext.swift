import Foundation

/// Tracks inserts, deletes, and fetches against a ModelContainer.
#if canImport(ObjectiveC)
@objc(Clone_ModelContext)
#endif
public final class ModelContext: NSObject {
    public let container: ModelContainer
    private let hydrator = ModelHydrator()

    private var insertions: [ObjectIdentifier: [AnyObject]] = [:]
    private var deletions: [ObjectIdentifier: [PersistentIdentifier]] = [:]
    private var saveGeneration: UInt64 = 0

    /// Incremented on each save. Used by @Query for dirty tracking.
    public var generation: UInt64 { saveGeneration }

    init(container: ModelContainer) {
        self.container = container
        super.init()
    }

    // MARK: - Insert

    public func insert<T: PersistentModel>(_ model: T) {
        let key = ObjectIdentifier(T.self)
        insertions[key, default: []].append(model)
    }

    // MARK: - Delete

    public func delete<T: PersistentModel>(_ model: T) {
        let key = ObjectIdentifier(T.self)
        deletions[key, default: []].append(model.persistentModelID)
    }

    /// Delete all instances of a model type. Matches Apple's `context.delete(model: Song.self)`.
    public func delete<T: PersistentModel>(model: T.Type) throws {
        let schema = T.schema
        let sql = "DELETE FROM \(schema.name)"
        try container.connection.execute(sql, parameters: [])
    }

    /// Delete instances matching a predicate. Matches Apple's `context.delete(model:where:)`.
    public func delete<T: PersistentModel>(model: T.Type, where predicate: _SQLPredicate<T>?) throws {
        let schema = T.schema
        if let predicate = predicate {
            let sql = "DELETE FROM \(schema.name) WHERE \(predicate.sql)"
            try container.connection.execute(sql, parameters: predicate.parameters)
        } else {
            try delete(model: model)
        }
    }

    /// Overload accepting Foundation.Predicate (Apple's public API).
    /// Converts the expression tree to SQL when possible, falls back to fetch-evaluate-delete.
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    public func delete<T: PersistentModel>(model: T.Type, where predicate: Foundation.Predicate<T>?) throws {
        guard let predicate else {
            try delete(model: model)
            return
        }
        // Try direct SQL conversion first
        if let sqlPred = PredicateConverter.convert(predicate) {
            try delete(model: model, where: sqlPred)
            return
        }
        // Fallback: fetch all, evaluate in-memory, delete matches
        let all = try fetchAll(model)
        for item in all {
            if try predicate.evaluate(item) {
                delete(item)
            }
        }
        try save()
    }

    // MARK: - Fetch

    public func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> [T] {
        let schema = T.schema
        var sql = "SELECT * FROM \(schema.name)"
        var params: [SQLiteValue] = []

        if let predicate = descriptor.predicate {
            sql += " WHERE \(predicate.sql)"
            params = predicate.parameters
        }

        if !descriptor.sortDescriptors.isEmpty {
            let orderClauses = descriptor.sortDescriptors.map { sort in
                "\(sort.key) \(sort.ascending ? "ASC" : "DESC")"
            }
            sql += " ORDER BY \(orderClauses.joined(separator: ", "))"
        }

        if let limit = descriptor.fetchLimit {
            sql += " LIMIT \(limit)"
        }
        if let offset = descriptor.fetchOffset {
            sql += " OFFSET \(offset)"
        }

        let rows = try container.connection.query(sql, parameters: params)
        // Deduplicate by primary key (id) to prevent crashes from duplicate business keys
        var seen = Set<String>()
        return rows.compactMap { row -> T? in
            guard let model = hydrator.hydrate(T.self, from: row) else { return nil }
            let id = model.persistentModelID.id.uuidString
            guard !seen.contains(id) else { return nil }
            seen.insert(id)
            return model
        }
    }

    /// Fetch all instances of a model type.
    public func fetchAll<T: PersistentModel>(_ type: T.Type) throws -> [T] {
        try fetch(FetchDescriptor<T>())
    }

    /// Fetch count.
    public func fetchCount<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> Int {
        let schema = T.schema
        var sql = "SELECT COUNT(*) FROM \(schema.name)"
        var params: [SQLiteValue] = []

        if let predicate = descriptor.predicate {
            sql += " WHERE \(predicate.sql)"
            params = predicate.parameters
        }

        let rows = try container.connection.query(sql, parameters: params)
        if let row = rows.first, case .integer(let count) = row[0] {
            return Int(count)
        }
        return 0
    }

    // MARK: - Save

    public func save() throws {
        try container.connection.transaction {
            // Process insertions.
            for (typeId, models) in insertions {
                for model in models {
                    try insertRow(model, typeId: typeId)
                }
            }

            // Process deletions.
            for (typeId, ids) in deletions {
                for id in ids {
                    try deleteRow(id: id, typeId: typeId)
                }
            }
        }

        insertions.removeAll()
        deletions.removeAll()
        saveGeneration += 1
    }

    // MARK: - Private

    private func insertRow(_ model: AnyObject, typeId: ObjectIdentifier) throws {
        guard let pm = model as? (any PersistentModel) else { return }
        let schema = type(of: pm).schema
        let values = hydrator.dehydrate(pm)
        let placeholders = Array(repeating: "?", count: values.count).joined(separator: ", ")
        let columns = ["id"] + schema.properties.map(\.name)
        let sql = "INSERT OR REPLACE INTO \(schema.name) (\(columns.joined(separator: ", "))) VALUES (\(placeholders))"
        try container.connection.execute(sql, parameters: values)
    }

    private func deleteRow(id: PersistentIdentifier, typeId: ObjectIdentifier) throws {
        // Find the schema by matching against registered schemas.
        for schema in container.schemas {
            let sql = "DELETE FROM \(schema.name) WHERE id = ?"
            let changed = try container.connection.execute(sql, parameters: [.text(id.id.uuidString)])
            if changed > 0 { return }
        }
    }
}
