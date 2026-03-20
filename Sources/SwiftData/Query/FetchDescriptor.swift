import Foundation

/// Sort descriptor for queries. Generic over the compared type to match Apple's API.
public struct SortDescriptor<Compared> {
    public let key: String
    public let ascending: Bool

    public init(_ keyPath: KeyPath<Compared, some Comparable>, order: SortOrder = .forward) {
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
    public var predicate: Predicate<T>?
    public var sortDescriptors: [SortDescriptor<T>]
    public var fetchLimit: Int?
    public var fetchOffset: Int?

    public init(predicate: Predicate<T>? = nil,
                sortBy: [SortDescriptor<T>] = [],
                limit: Int? = nil,
                offset: Int? = nil) {
        self.predicate = predicate
        self.sortDescriptors = sortBy
        self.fetchLimit = limit
        self.fetchOffset = offset
    }
}
