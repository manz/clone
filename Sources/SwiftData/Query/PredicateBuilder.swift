import Foundation

/// Type-safe column reference for building predicates.
public struct Column<Model: PersistentModel, Value> {
    public let name: String

    public init(_ name: String) {
        self.name = name
    }
}

// MARK: - Equatable Operators

public func == <M, V: Equatable>(lhs: Column<M, V>, rhs: V) -> Predicate<M> where V: SQLiteBindable {
    Predicate(sql: "\(lhs.name) = ?", parameters: [rhs.sqliteValue])
}

public func != <M, V: Equatable>(lhs: Column<M, V>, rhs: V) -> Predicate<M> where V: SQLiteBindable {
    Predicate(sql: "\(lhs.name) != ?", parameters: [rhs.sqliteValue])
}

// MARK: - Comparable Operators

public func > <M, V: Comparable>(lhs: Column<M, V>, rhs: V) -> Predicate<M> where V: SQLiteBindable {
    Predicate(sql: "\(lhs.name) > ?", parameters: [rhs.sqliteValue])
}

public func < <M, V: Comparable>(lhs: Column<M, V>, rhs: V) -> Predicate<M> where V: SQLiteBindable {
    Predicate(sql: "\(lhs.name) < ?", parameters: [rhs.sqliteValue])
}

public func >= <M, V: Comparable>(lhs: Column<M, V>, rhs: V) -> Predicate<M> where V: SQLiteBindable {
    Predicate(sql: "\(lhs.name) >= ?", parameters: [rhs.sqliteValue])
}

public func <= <M, V: Comparable>(lhs: Column<M, V>, rhs: V) -> Predicate<M> where V: SQLiteBindable {
    Predicate(sql: "\(lhs.name) <= ?", parameters: [rhs.sqliteValue])
}

// MARK: - String-specific Operators

extension Column where Value == String {
    public func contains(_ substring: String) -> Predicate<Model> {
        Predicate(sql: "\(name) LIKE ?", parameters: [.text("%\(substring)%")])
    }

    public func hasPrefix(_ prefix: String) -> Predicate<Model> {
        Predicate(sql: "\(name) LIKE ?", parameters: [.text("\(prefix)%")])
    }

    public func hasSuffix(_ suffix: String) -> Predicate<Model> {
        Predicate(sql: "\(name) LIKE ?", parameters: [.text("%\(suffix)")])
    }
}

// MARK: - SQLiteBindable

/// Protocol for types that can be bound to SQLite parameters.
public protocol SQLiteBindable {
    var sqliteValue: SQLiteValue { get }
}

extension String: SQLiteBindable {
    public var sqliteValue: SQLiteValue { .text(self) }
}

extension Int: SQLiteBindable {
    public var sqliteValue: SQLiteValue { .integer(Int64(self)) }
}

extension Int64: SQLiteBindable {
    public var sqliteValue: SQLiteValue { .integer(self) }
}

extension Double: SQLiteBindable {
    public var sqliteValue: SQLiteValue { .real(self) }
}

extension Float: SQLiteBindable {
    public var sqliteValue: SQLiteValue { .real(Double(self)) }
}

extension Bool: SQLiteBindable {
    public var sqliteValue: SQLiteValue { .integer(self ? 1 : 0) }
}

extension UUID: SQLiteBindable {
    public var sqliteValue: SQLiteValue { .text(self.uuidString) }
}

extension Date: SQLiteBindable {
    public var sqliteValue: SQLiteValue { .text(ISO8601DateFormatter().string(from: self)) }
}
