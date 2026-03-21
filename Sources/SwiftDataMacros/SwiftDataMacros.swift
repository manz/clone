import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - @Model

/// `@Model` attached macro — adds PersistentModel conformance and generates
/// a minimal `schema` + `init()` + `persistentModelID` so the type compiles.
public struct ModelMacro: MemberMacro, ExtensionMacro {

    // MARK: ExtensionMacro — add `: PersistentModel`

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let ext: DeclSyntax = """
        extension \(type.trimmed): PersistentModel {}
        """
        return [ext.cast(ExtensionDeclSyntax.self)]
    }

    // MARK: MemberMacro — add persistentModelID, schema, init()

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Extract stored properties for schema generation
        let members = declaration.memberBlock.members
        var propertyEntries: [String] = []

        for member in members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self),
                  varDecl.bindingSpecifier.text == "var" else { continue }
            for binding in varDecl.bindings {
                guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { continue }
                // Skip computed properties (those with accessor blocks that aren't just willSet/didSet)
                if let accessor = binding.accessorBlock {
                    if accessor.accessors.is(AccessorDeclListSyntax.self) {
                        // Has get/set — computed, skip
                        continue
                    }
                }
                // Skip if already persistentModelID
                if name == "persistentModelID" { continue }

                let propType = inferPropertyType(binding: binding)
                propertyEntries.append(
                    "PropertySchema(name: \"\(name)\", type: .\(propType))"
                )
            }
        }

        let schemaName = declaration.as(ClassDeclSyntax.self)?.name.text ?? "Unknown"

        let propertiesLiteral = propertyEntries.joined(separator: ", ")

        // Check if the class already defines an init() to avoid "invalid redeclaration"
        let hasExistingInit = members.contains { member in
            guard let initDecl = member.decl.as(InitializerDeclSyntax.self) else { return false }
            let params = initDecl.signature.parameterClause.parameters
            return params.isEmpty
        }

        var result: [DeclSyntax] = [
            """
            public var persistentModelID: PersistentIdentifier = PersistentIdentifier()
            """,
            """
            public static var schema: ModelSchema {
                ModelSchema(name: \"\(raw: schemaName)\", properties: [\(raw: propertiesLiteral)])
            }
            """,
        ]

        if !hasExistingInit {
            result.append("""
            public required init() {}
            """)
        }

        return result
    }

    private static func inferPropertyType(binding: PatternBindingSyntax) -> String {
        guard let typeAnnotation = binding.typeAnnotation?.type else { return "string" }
        let typeText = typeAnnotation.description.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip Optional wrapper
        var inner = typeText
        if inner.hasSuffix("?") { inner = String(inner.dropLast()) }
        if inner.hasPrefix("Optional<") { inner = String(inner.dropFirst(9).dropLast()) }

        switch inner {
        case "String": return "string"
        case "Int": return "int"
        case "Int64": return "int64"
        case "Double": return "double"
        case "Float": return "float"
        case "Bool": return "bool"
        case "Date": return "date"
        case "Data": return "data"
        case "UUID": return "uuid"
        default: return "string"
        }
    }
}

// MARK: - @Relationship

/// `@Relationship` — no-op marker. The property is kept as-is.
public struct RelationshipMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}

// MARK: - @Attribute

/// `@Attribute` — no-op marker for property attributes.
public struct AttributeMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}

// MARK: - #Predicate

/// `#Predicate` — evaluates to a nil Predicate (no filtering). Real predicates need
/// full expression parsing; this stub lets code compile.
public struct PredicateMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        // Return nil — the macro declaration's return type provides the concrete generic.
        return "nil"
    }
}

// MARK: - #Preview

/// `#Preview` — discards the body entirely.
public struct PreviewMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Just discard the preview body
        []
    }
}

// MARK: - #Index (freestanding declaration form)

/// `#Index<T>([\.prop])` — no-op declaration macro.
public struct IndexDeclMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}

// MARK: - #Unique (freestanding declaration form)

/// `#Unique<T>([\.prop])` — no-op declaration macro.
public struct UniqueDeclMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}

// MARK: - @Index

/// `@Index` — no-op marker.
public struct IndexMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}

// MARK: - @Unique

/// `@Unique` — no-op marker.
public struct UniqueMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}

// MARK: - @ModelActor

/// `@ModelActor` — adds modelContainer/modelContext properties.
public struct ModelActorMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return [
            "public let modelContainer: ModelContainer",
            "public var modelContext: ModelContext { modelContainer.mainContext }",
            "public init(modelContainer: ModelContainer) { self.modelContainer = modelContainer }",
        ]
    }
}

// MARK: - Plugin

@main
struct SwiftDataMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ModelMacro.self,
        RelationshipMacro.self,
        AttributeMacro.self,
        PredicateMacro.self,
        PreviewMacro.self,
        IndexMacro.self,
        UniqueMacro.self,
        IndexDeclMacro.self,
        UniqueDeclMacro.self,
        ModelActorMacro.self,
    ]
}
