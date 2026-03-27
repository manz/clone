import Foundation

/// Sort descriptor for queries. Generic over the compared type to match Apple's API.
public struct SortDescriptor<Compared> {
    public let key: String
    public let ascending: Bool

    public init<Value>(_ keyPath: KeyPath<Compared, Value>, order: SortOrder = .forward) {
        self.key = "\(keyPath)"
        self.ascending = order == .forward
    }

    public init(_ key: String, ascending: Bool = true) {
        self.key = key
        self.ascending = ascending
    }
}

/// Sort order for SortDescriptor.
public enum SortOrder: Sendable {
    case forward, reverse
}

/// Describes a fetch operation: predicate + sort + limit.
public struct FetchDescriptor<T: PersistentModel> {
    public var predicate: _SQLPredicate<T>?
    public var sortDescriptors: [SortDescriptor<T>]
    public var fetchLimit: Int?
    public var fetchOffset: Int?

    /// Init with no predicate (fetch all).
    public init(sortBy: [SortDescriptor<T>] = [],
                limit: Int? = nil,
                offset: Int? = nil) {
        self.predicate = nil
        self.sortDescriptors = sortBy
        self.fetchLimit = limit
        self.fetchOffset = offset
    }

    /// Init with _SQLPredicate (Column-based predicates). Internal use.
    public init(sqlPredicate: _SQLPredicate<T>?,
                sortBy: [SortDescriptor<T>] = [],
                limit: Int? = nil,
                offset: Int? = nil) {
        self.predicate = sqlPredicate
        self.sortDescriptors = sortBy
        self.fetchLimit = limit
        self.fetchOffset = offset
    }

    /// Init with Foundation.Predicate (from #Predicate { ... }).
    /// This is the primary API — matches Apple's SwiftData.
    public init(predicate: Foundation.Predicate<T>,
                sortBy: [SortDescriptor<T>] = [],
                limit: Int? = nil,
                offset: Int? = nil) {
        self.predicate = PredicateConverter.convert(predicate)
        self.sortDescriptors = sortBy
        self.fetchLimit = limit
        self.fetchOffset = offset
    }
}
