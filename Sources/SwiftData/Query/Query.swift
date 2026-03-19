import Foundation

/// @Query property wrapper with dirty-flag invalidation.
/// Re-fetches from the context when the context's save generation changes.
@propertyWrapper
public final class Query<T: PersistentModel> {
    private let descriptor: FetchDescriptor<T>
    private var cachedResults: [T] = []
    private var lastGeneration: UInt64 = UInt64.max
    private weak var context: ModelContext?

    public init(sort sortDescriptors: [SortDescriptor] = [],
                predicate: Predicate<T>? = nil,
                limit: Int? = nil) {
        self.descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: sortDescriptors,
            limit: limit
        )
    }

    /// Must be called before first access to wire up the context.
    public func bind(to context: ModelContext) {
        self.context = context
        self.lastGeneration = UInt64.max // Force re-fetch on next access.
    }

    public var wrappedValue: [T] {
        guard let ctx = context else { return [] }
        if ctx.generation != lastGeneration {
            cachedResults = (try? ctx.fetch(descriptor)) ?? []
            lastGeneration = ctx.generation
        }
        return cachedResults
    }

    /// Force invalidation.
    public func invalidate() {
        lastGeneration = UInt64.max
    }
}
