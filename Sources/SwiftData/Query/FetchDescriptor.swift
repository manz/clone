import Foundation

/// Sort descriptor for queries.
public struct SortDescriptor {
    public let key: String
    public let ascending: Bool

    public init(_ key: String, ascending: Bool = true) {
        self.key = key
        self.ascending = ascending
    }
}

/// Describes a fetch operation: predicate + sort + limit.
public struct FetchDescriptor<T: PersistentModel> {
    public var predicate: Predicate<T>?
    public var sortDescriptors: [SortDescriptor]
    public var fetchLimit: Int?
    public var fetchOffset: Int?

    public init(predicate: Predicate<T>? = nil,
                sortBy: [SortDescriptor] = [],
                limit: Int? = nil,
                offset: Int? = nil) {
        self.predicate = predicate
        self.sortDescriptors = sortBy
        self.fetchLimit = limit
        self.fetchOffset = offset
    }
}
