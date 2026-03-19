import Foundation

/// A type-safe SQL predicate with bound parameters.
public struct Predicate<Model: PersistentModel> {
    public let sql: String
    public let parameters: [SQLiteValue]

    public init(sql: String, parameters: [SQLiteValue] = []) {
        self.sql = sql
        self.parameters = parameters
    }
}

// MARK: - Combinators

public func && <M: PersistentModel>(lhs: Predicate<M>, rhs: Predicate<M>) -> Predicate<M> {
    Predicate(sql: "(\(lhs.sql)) AND (\(rhs.sql))", parameters: lhs.parameters + rhs.parameters)
}

public func || <M: PersistentModel>(lhs: Predicate<M>, rhs: Predicate<M>) -> Predicate<M> {
    Predicate(sql: "(\(lhs.sql)) OR (\(rhs.sql))", parameters: lhs.parameters + rhs.parameters)
}

public prefix func ! <M: PersistentModel>(pred: Predicate<M>) -> Predicate<M> {
    Predicate(sql: "NOT (\(pred.sql))", parameters: pred.parameters)
}
