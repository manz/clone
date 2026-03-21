import Foundation

// MARK: - Foundation.Predicate → _SQLPredicate converter

/// Converts a Foundation.Predicate expression tree into SQL WHERE clause + parameters.
/// Walks the tree using type-erasing protocols to access generic PredicateExpressions nodes.
/// Returns nil for expressions it can't convert (caller falls back to in-memory evaluation).
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
enum PredicateConverter {

    static func convert<T: PersistentModel>(_ predicate: Foundation.Predicate<T>) -> _SQLPredicate<T>? {
        guard let result = convertExpression(predicate.expression) else { return nil }
        return _SQLPredicate(sql: result.sql, parameters: result.params)
    }

    // MARK: - Expression walking

    /// Recursively converts an expression node to SQL. Returns nil if unsupported.
    static func convertExpression(_ expr: Any) -> (sql: String, params: [SQLiteValue])? {
        // -- Comparisons --
        if let eq = expr as? _PredEqual {
            return convertBinary(eq._lhs, eq._rhs, op: "=")
        }
        if let neq = expr as? _PredNotEqual {
            return convertBinary(neq._lhs, neq._rhs, op: "!=")
        }
        if let cmp = expr as? _PredComparison {
            let op: String
            switch cmp._cmpOp {
            case .lt: op = "<"
            case .le: op = "<="
            case .gt: op = ">"
            case .ge: op = ">="
            }
            return convertBinary(cmp._lhs, cmp._rhs, op: op)
        }

        // -- Logical --
        if let conj = expr as? _PredConjunction {
            guard let l = convertExpression(conj._lhs),
                  let r = convertExpression(conj._rhs) else { return nil }
            return ("(\(l.sql)) AND (\(r.sql))", l.params + r.params)
        }
        if let disj = expr as? _PredDisjunction {
            guard let l = convertExpression(disj._lhs),
                  let r = convertExpression(disj._rhs) else { return nil }
            return ("(\(l.sql)) OR (\(r.sql))", l.params + r.params)
        }
        if let neg = expr as? _PredNegation {
            guard let inner = convertExpression(neg._inner) else { return nil }
            return ("NOT (\(inner.sql))", inner.params)
        }

        // -- Arithmetic --
        if let arith = expr as? _PredArithmetic {
            guard let l = convertSQL(arith._lhs),
                  let r = convertSQL(arith._rhs) else { return nil }
            let op: String
            switch arith._arithOp {
            case .add: op = "+"
            case .sub: op = "-"
            case .mul: op = "*"
            }
            return ("(\(l.sql) \(op) \(r.sql))", l.params + r.params)
        }
        if let div = expr as? _PredDivision {
            guard let l = convertSQL(div._lhs),
                  let r = convertSQL(div._rhs) else { return nil }
            return ("(\(l.sql) / \(r.sql))", l.params + r.params)
        }
        if let rem = expr as? _PredRemainder {
            guard let l = convertSQL(rem._lhs),
                  let r = convertSQL(rem._rhs) else { return nil }
            return ("(\(l.sql) % \(r.sql))", l.params + r.params)
        }
        if let neg = expr as? _PredUnaryMinus {
            guard let inner = convertSQL(neg._inner) else { return nil }
            return ("(-\(inner.sql))", inner.params)
        }

        // -- Sequence contains (IN) --
        if let contains = expr as? _PredSequenceContains {
            // element IN column or column contains element
            if let col = extractColumnName(contains._sequence),
               let val = extractValue(contains._element) {
                return ("\(col) LIKE '%' || ? || '%'", [val])
            }
            // Value array contains keypath: keypath IN (?, ?, ...)
            if let col = extractColumnName(contains._element),
               let values = extractValueArray(contains._sequence) {
                let placeholders = values.map { _ in "?" }.joined(separator: ", ")
                return ("\(col) IN (\(placeholders))", values)
            }
            return nil
        }

        // -- Range contains (BETWEEN) --
        if let range = expr as? _PredRangeContains {
            if let col = extractColumnName(range._element),
               let lo = extractValue(range._lower),
               let hi = extractValue(range._upper) {
                return ("\(col) BETWEEN ? AND ?", [lo, hi])
            }
            return nil
        }

        // -- Nil checks --
        if let _ = expr as? _PredNilLiteral {
            return ("NULL", [])
        }
        if let coalesce = expr as? _PredNilCoalesce {
            guard let l = convertSQL(coalesce._lhs),
                  let r = convertSQL(coalesce._rhs) else { return nil }
            return ("COALESCE(\(l.sql), \(r.sql))", l.params + r.params)
        }
        if let unwrap = expr as? _PredForcedUnwrap {
            return convertSQL(unwrap._inner)
        }
        if let flatMap = expr as? _PredOptionalFlatMap {
            // Optional chaining: if wrapped is not null, evaluate transform
            guard let wrappedSQL = convertSQL(flatMap._wrapped),
                  let transformSQL = convertExpression(flatMap._transform) else { return nil }
            return ("CASE WHEN \(wrappedSQL.sql) IS NOT NULL THEN \(transformSQL.sql) ELSE NULL END",
                    wrappedSQL.params + transformSQL.params)
        }

        // -- Conditional (ternary) --
        if let cond = expr as? _PredConditional {
            guard let test = convertExpression(cond._test),
                  let ifTrue = convertSQL(cond._trueBranch),
                  let ifFalse = convertSQL(cond._falseBranch) else { return nil }
            return ("CASE WHEN \(test.sql) THEN \(ifTrue.sql) ELSE \(ifFalse.sql) END",
                    test.params + ifTrue.params + ifFalse.params)
        }

        // -- String operations --
        if let sc = expr as? _PredStringContains {
            if let col = extractColumnName(sc._root),
               let val = extractValue(sc._other) {
                return ("\(col) LIKE '%' || ? || '%'", [val])
            }
            return nil
        }
        if let sp = expr as? _PredStringHasPrefix {
            if let col = extractColumnName(sp._root),
               let val = extractValue(sp._other) {
                return ("\(col) LIKE ? || '%'", [val])
            }
            return nil
        }
        if let ss = expr as? _PredStringHasSuffix {
            if let col = extractColumnName(ss._root),
               let val = extractValue(ss._other) {
                return ("\(col) LIKE '%' || ?", [val])
            }
            return nil
        }
        if let sci = expr as? _PredStringCaseInsensitiveCompare {
            if let col = extractColumnName(sci._root),
               let val = extractValue(sci._other) {
                return ("\(col) = ? COLLATE NOCASE", [val])
            }
            return nil
        }

        // -- Leaf nodes (used inside binary expressions) --
        // These don't produce standalone boolean SQL, but convertSQL handles them.
        return nil
    }

    // MARK: - Convert to SQL fragment (not necessarily boolean)

    /// Converts an expression to a SQL fragment (column name, literal, or sub-expression).
    /// Used for non-boolean sub-expressions (arithmetic operands, COALESCE args, etc.).
    private static func convertSQL(_ expr: Any) -> (sql: String, params: [SQLiteValue])? {
        if let col = extractColumnName(expr) {
            return (col, [])
        }
        if let val = extractValue(expr) {
            return ("?", [val])
        }
        // Recurse for compound expressions
        return convertExpression(expr)
    }

    // MARK: - Binary comparison helper

    private static func convertBinary(_ lhs: Any, _ rhs: Any, op: String) -> (sql: String, params: [SQLiteValue])? {
        // Try both orientations: column op value, value op column
        if let lSQL = convertSQL(lhs), let rSQL = convertSQL(rhs) {
            // If both sides are just a column and a param, keep it simple
            return ("\(lSQL.sql) \(op) \(rSQL.sql)", lSQL.params + rSQL.params)
        }
        return nil
    }

    // MARK: - Column name extraction

    private static func extractColumnName(_ expr: Any) -> String? {
        guard let kp = expr as? _PredKeyPath else { return nil }
        return kp._columnName
    }

    // MARK: - Value extraction

    private static func extractValue(_ expr: Any) -> SQLiteValue? {
        guard let val = expr as? _PredValue else { return nil }
        return anyToSQLiteValue(val._anyValue)
    }

    private static func extractValueArray(_ expr: Any) -> [SQLiteValue]? {
        guard let val = expr as? _PredValue else { return nil }
        let raw = val._anyValue
        // Try to iterate as a sequence of bindable values
        if let arr = raw as? [String] { return arr.map { .text($0) } }
        if let arr = raw as? [Int] { return arr.map { .integer(Int64($0)) } }
        if let arr = raw as? [Int64] { return arr.map { .integer($0) } }
        if let arr = raw as? [Double] { return arr.map { .real($0) } }
        return nil
    }

    static func anyToSQLiteValue(_ value: Any) -> SQLiteValue? {
        switch value {
        case let v as String: return .text(v)
        case let v as Int: return .integer(Int64(v))
        case let v as Int64: return .integer(v)
        case let v as Int32: return .integer(Int64(v))
        case let v as Int16: return .integer(Int64(v))
        case let v as Int8: return .integer(Int64(v))
        case let v as UInt: return .integer(Int64(v))
        case let v as UInt64: return .integer(Int64(v))
        case let v as Double: return .real(v)
        case let v as Float: return .real(Double(v))
        case let v as Bool: return .integer(v ? 1 : 0)
        case let v as UUID: return .text(v.uuidString)
        case let v as Date: return .text(ISO8601DateFormatter().string(from: v))
        case let v as Data: return .blob(v)
        default: return nil
        }
    }
}

// MARK: - Type-erasing protocols
//
// Each protocol exposes the children of a specific PredicateExpressions node as `Any`,
// letting us walk the tree without knowing the concrete generic parameters.

// -- Comparison / Equality --

protocol _PredEqual { var _lhs: Any { get }; var _rhs: Any { get } }
protocol _PredNotEqual { var _lhs: Any { get }; var _rhs: Any { get } }

enum _CmpOp { case lt, le, gt, ge }
protocol _PredComparison { var _lhs: Any { get }; var _rhs: Any { get }; var _cmpOp: _CmpOp { get } }

// -- Logical --

protocol _PredConjunction { var _lhs: Any { get }; var _rhs: Any { get } }
protocol _PredDisjunction { var _lhs: Any { get }; var _rhs: Any { get } }
protocol _PredNegation { var _inner: Any { get } }

// -- Arithmetic --

enum _ArithOp { case add, sub, mul }
protocol _PredArithmetic { var _lhs: Any { get }; var _rhs: Any { get }; var _arithOp: _ArithOp { get } }
protocol _PredDivision { var _lhs: Any { get }; var _rhs: Any { get } }
protocol _PredRemainder { var _lhs: Any { get }; var _rhs: Any { get } }
protocol _PredUnaryMinus { var _inner: Any { get } }

// -- Sequence --

protocol _PredSequenceContains { var _sequence: Any { get }; var _element: Any { get } }

// -- Range --

protocol _PredRangeContains { var _element: Any { get }; var _lower: Any { get }; var _upper: Any { get } }

// -- Optional --

protocol _PredNilLiteral {}
protocol _PredNilCoalesce { var _lhs: Any { get }; var _rhs: Any { get } }
protocol _PredForcedUnwrap { var _inner: Any { get } }
protocol _PredOptionalFlatMap { var _wrapped: Any { get }; var _transform: Any { get } }

// -- Conditional --

protocol _PredConditional { var _test: Any { get }; var _trueBranch: Any { get }; var _falseBranch: Any { get } }

// -- String --

protocol _PredStringContains { var _root: Any { get }; var _other: Any { get } }
protocol _PredStringHasPrefix { var _root: Any { get }; var _other: Any { get } }
protocol _PredStringHasSuffix { var _root: Any { get }; var _other: Any { get } }
protocol _PredStringCaseInsensitiveCompare { var _root: Any { get }; var _other: Any { get } }

// -- Leaf --

protocol _PredKeyPath { var _columnName: String? { get } }
protocol _PredValue { var _anyValue: Any { get } }

// MARK: - Conformances

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.Equal: _PredEqual {
    var _lhs: Any { lhs }
    var _rhs: Any { rhs }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.NotEqual: _PredNotEqual {
    var _lhs: Any { lhs }
    var _rhs: Any { rhs }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.Comparison: _PredComparison {
    var _lhs: Any { lhs }
    var _rhs: Any { rhs }
    var _cmpOp: _CmpOp {
        switch op {
        case .lessThan: return .lt
        case .lessThanOrEqual: return .le
        case .greaterThan: return .gt
        case .greaterThanOrEqual: return .ge
        @unknown default: return .lt
        }
    }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.Conjunction: _PredConjunction {
    var _lhs: Any { lhs }
    var _rhs: Any { rhs }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.Disjunction: _PredDisjunction {
    var _lhs: Any { lhs }
    var _rhs: Any { rhs }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.Negation: _PredNegation {
    var _inner: Any { wrapped }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.Arithmetic: _PredArithmetic {
    var _lhs: Any { lhs }
    var _rhs: Any { rhs }
    var _arithOp: _ArithOp {
        switch op {
        case .add: return .add
        case .subtract: return .sub
        case .multiply: return .mul
        @unknown default: return .add
        }
    }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.FloatDivision: _PredDivision {
    var _lhs: Any { lhs }
    var _rhs: Any { rhs }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.IntDivision: _PredDivision {
    var _lhs: Any { lhs }
    var _rhs: Any { rhs }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.IntRemainder: _PredRemainder {
    var _lhs: Any { lhs }
    var _rhs: Any { rhs }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.UnaryMinus: _PredUnaryMinus {
    var _inner: Any { wrapped }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.SequenceContains: _PredSequenceContains {
    var _sequence: Any { sequence }
    var _element: Any { element }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.NilCoalesce: _PredNilCoalesce {
    var _lhs: Any { lhs }
    var _rhs: Any { rhs }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.NilLiteral: _PredNilLiteral {}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.ForcedUnwrap: _PredForcedUnwrap {
    var _inner: Any { inner }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.OptionalFlatMap: _PredOptionalFlatMap {
    var _wrapped: Any { wrapped }
    var _transform: Any { transform }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.Conditional: _PredConditional {
    var _test: Any { test }
    var _trueBranch: Any { trueBranch }
    var _falseBranch: Any { falseBranch }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.KeyPath: _PredKeyPath {
    var _columnName: String? {
        let desc = String(describing: keyPath)
        guard let dot = desc.lastIndex(of: ".") else { return nil }
        return String(desc[desc.index(after: dot)...])
    }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.Value: _PredValue {
    var _anyValue: Any { value }
}

// MARK: - String expression conformances (SequenceContainsWhere used for .contains/.hasPrefix/.hasSuffix)

// Foundation's #Predicate { $0.name.contains("foo") } emits SequenceContainsWhere
// with a character-level test. For localizedStandardContains and similar, the macro
// emits dedicated expression types. We handle the common string forms here.

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.SequenceStartsWith: _PredStringHasPrefix {
    var _root: Any { base }
    var _other: Any { prefix }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.StringCaseInsensitiveCompare: _PredStringCaseInsensitiveCompare {
    var _root: Any { root }
    var _other: Any { other }
}

// Note: PredicateExpressions.StringLocalizedStandardContains is #if FOUNDATION_FRAMEWORK only.
// On Apple platforms it's available; on open-source swift-foundation it's not.
// We handle it if present via _PredStringContains conformance.
#if canImport(Foundation, _version: 0.0.1)
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.SequenceContainsWhere: _PredStringContains {
    var _root: Any { sequence }
    var _other: Any { test }
}
#endif

// MARK: - RangeExpressionContains

// Foundation uses RangeExpressionContains for range.contains(element).
// We need a protocol to extract the range bounds and element.
// The range itself is built from PredicateExpressions.ClosedRange or PredicateExpressions.Range,
// which hold lower/upper. We extract via a nested protocol.

protocol _PredRangeBounds { var _lower: Any { get }; var _upper: Any { get } }

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.ClosedRange: _PredRangeBounds {
    var _lower: Any { lower }
    var _upper: Any { upper }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.Range: _PredRangeBounds {
    var _lower: Any { lower }
    var _upper: Any { upper }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.RangeExpressionContains: _PredRangeContains {
    var _element: Any { element }
    var _lower: Any {
        if let bounds = range as? _PredRangeBounds { return bounds._lower }
        return range
    }
    var _upper: Any {
        if let bounds = range as? _PredRangeBounds { return bounds._upper }
        return range
    }
}
