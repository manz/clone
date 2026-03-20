// MARK: - SwiftData Macro Declarations

/// Marks a class as a persistent model. Generates PersistentModel conformance,
/// schema, persistentModelID, and required init().
@attached(member, names: named(persistentModelID), named(schema), named(init))
@attached(extension, conformances: PersistentModel)
public macro Model() = #externalMacro(module: "SwiftDataMacros", type: "ModelMacro")

/// Marks a property as a relationship.
@attached(peer)
public macro Relationship(
    _ options: Any?...,
    deleteRule: DeleteRule = .nullify,
    inverse: AnyKeyPath? = nil
) = #externalMacro(module: "SwiftDataMacros", type: "RelationshipMacro")

/// Marks a property with storage attributes.
@attached(peer)
public macro Attribute(_ options: Any?...) = #externalMacro(module: "SwiftDataMacros", type: "AttributeMacro")

/// Creates a type-safe predicate. Stub: evaluates to nil (no filtering).
/// Uses a single generic parameter (not variadic) since Clone predicates always filter one model type.
/// Fully qualified to avoid ambiguity with Foundation.Predicate.
@freestanding(expression)
public macro Predicate<T: PersistentModel>(_ body: (T) -> Bool) -> SwiftData.Predicate<T>? = #externalMacro(module: "SwiftDataMacros", type: "PredicateMacro")

/// Marks properties for indexing (attached form).
@attached(peer)
public macro Index(_ keyPaths: Any?...) = #externalMacro(module: "SwiftDataMacros", type: "IndexMacro")

/// Marks properties for uniqueness constraints (attached form).
@attached(peer)
public macro Unique(_ keyPaths: Any?...) = #externalMacro(module: "SwiftDataMacros", type: "UniqueMacro")

/// `#Index<T>([\.prop])` — freestanding expression form used inside @Model classes.
@freestanding(declaration)
public macro Index<T: PersistentModel>(_ keyPaths: [PartialKeyPath<T>]...) = #externalMacro(module: "SwiftDataMacros", type: "IndexDeclMacro")

/// `#Unique<T>([\.prop])` — freestanding expression form used inside @Model classes.
@freestanding(declaration)
public macro Unique<T: PersistentModel>(_ keyPaths: [PartialKeyPath<T>]...) = #externalMacro(module: "SwiftDataMacros", type: "UniqueDeclMacro")

/// Marks an actor as a model actor with container/context access.
@attached(member, names: named(modelContainer), named(modelContext), named(init))
public macro ModelActor() = #externalMacro(module: "SwiftDataMacros", type: "ModelActorMacro")

// MARK: - Schema type (used by migration plans)

public enum Schema {
    public typealias Version = SchemaVersion
}

public struct SchemaVersion: Hashable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(_ major: Int, _ minor: Int, _ patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
}
