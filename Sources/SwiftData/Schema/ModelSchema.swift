import Foundation

/// Describes the type of a persisted property.
public enum PropertyType: Sendable {
    case string
    case int
    case int64
    case double
    case float
    case bool
    case date
    case data
    case uuid
}

/// Describes a single persisted property (column).
public struct PropertySchema: Sendable {
    public let name: String
    public let type: PropertyType
    public let isOptional: Bool
    public let defaultValue: String?

    public init(name: String, type: PropertyType, isOptional: Bool = false, defaultValue: String? = nil) {
        self.name = name
        self.type = type
        self.isOptional = isOptional
        self.defaultValue = defaultValue
    }

    /// SQL type for this property.
    public var sqlType: String {
        switch type {
        case .string, .uuid, .date:
            return "TEXT"
        case .int, .int64, .bool:
            return "INTEGER"
        case .double, .float:
            return "REAL"
        case .data:
            return "BLOB"
        }
    }
}

/// Relationship cardinality.
public enum RelationshipCardinality: Sendable {
    case toOne
    case toMany
}

/// Deletion rule for relationships.
public enum DeleteRule: Sendable {
    case cascade
    case nullify
    case noAction
}

/// Describes a relationship between models.
public struct RelationshipDescriptor: Sendable {
    public let name: String
    public let destinationTable: String
    public let cardinality: RelationshipCardinality
    public let deleteRule: DeleteRule
    public let inverseKey: String?

    public init(name: String, destination: String, cardinality: RelationshipCardinality,
                deleteRule: DeleteRule = .nullify, inverseKey: String? = nil) {
        self.name = name
        self.destinationTable = destination
        self.cardinality = cardinality
        self.deleteRule = deleteRule
        self.inverseKey = inverseKey
    }
}

/// Full schema for a PersistentModel — table name, columns, relationships.
public struct ModelSchema: Sendable {
    public let name: String
    public let properties: [PropertySchema]
    public let relationships: [RelationshipDescriptor]

    public init(name: String, properties: [PropertySchema], relationships: [RelationshipDescriptor] = []) {
        self.name = name
        self.properties = properties
        self.relationships = relationships
    }

    /// Generate CREATE TABLE SQL.
    public func createTableSQL() -> String {
        var columns = ["id TEXT PRIMARY KEY NOT NULL"]
        for prop in properties {
            var col = "\(prop.name) \(prop.sqlType)"
            if !prop.isOptional {
                col += " NOT NULL"
            }
            if let def = prop.defaultValue {
                col += " DEFAULT \(def)"
            }
            columns.append(col)
        }
        // ToOne relationships become foreign key columns.
        for rel in relationships where rel.cardinality == .toOne {
            columns.append("\(rel.name)_id TEXT REFERENCES \(rel.destinationTable)(id)")
        }
        return "CREATE TABLE IF NOT EXISTS \(name) (\(columns.joined(separator: ", ")))"
    }
}
