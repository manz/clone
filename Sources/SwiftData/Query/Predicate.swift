import Foundation

/// A type-safe SQL predicate with bound parameters (internal to Clone's SwiftData).
public struct _SQLPredicate<Model: PersistentModel> {
    public let sql: String
    public let parameters: [SQLiteValue]

    public init(sql: String, parameters: [SQLiteValue] = []) {
        self.sql = sql
        self.parameters = parameters
    }
}

// MARK: - Combinators

public func && <M: PersistentModel>(lhs: _SQLPredicate<M>, rhs: _SQLPredicate<M>) -> _SQLPredicate<M> {
    _SQLPredicate(sql: "(\(lhs.sql)) AND (\(rhs.sql))", parameters: lhs.parameters + rhs.parameters)
}

public func || <M: PersistentModel>(lhs: _SQLPredicate<M>, rhs: _SQLPredicate<M>) -> _SQLPredicate<M> {
    _SQLPredicate(sql: "(\(lhs.sql)) OR (\(rhs.sql))", parameters: lhs.parameters + rhs.parameters)
}

public prefix func ! <M: PersistentModel>(pred: _SQLPredicate<M>) -> _SQLPredicate<M> {
    _SQLPredicate(sql: "NOT (\(pred.sql))", parameters: pred.parameters)
}
