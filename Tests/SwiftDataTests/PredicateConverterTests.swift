import Testing
import Foundation
@testable import SwiftData

// MARK: - Foundation.Predicate → SQL tests

@Test func foundationPredicateEquality() throws {
    let container = try ModelContainer(for: [Bookmark.self],
                                       configuration: ModelConfiguration(isStoredInMemoryOnly: true))
    let ctx = container.mainContext

    let bm1 = Bookmark(); bm1.name = "Alpha"; bm1.path = "/a"; bm1.pinned = false; ctx.insert(bm1)
    let bm2 = Bookmark(); bm2.name = "Beta"; bm2.path = "/b"; bm2.pinned = true; ctx.insert(bm2)
    try ctx.save()

    let foundationPred: Foundation.Predicate<Bookmark> = #Predicate { $0.name == "Beta" }
    let descriptor = FetchDescriptor<Bookmark>(predicate: foundationPred)
    // The FetchDescriptor should use the Foundation.Predicate init and convert to SQL
    #expect(descriptor.predicate != nil, "Predicate should be converted to SQL")
    #expect(descriptor.predicate?.sql.contains("name") == true,
            "SQL should reference 'name', got: \(descriptor.predicate?.sql ?? "nil")")

    let results = try ctx.fetch(descriptor)
    #expect(results.count == 1)
    #expect(results[0].name == "Beta")
}

@Test func foundationPredicateAndOr() throws {
    let container = try ModelContainer(for: [Bookmark.self],
                                       configuration: ModelConfiguration(isStoredInMemoryOnly: true))
    let ctx = container.mainContext

    let bm1 = Bookmark(); bm1.name = "A"; bm1.path = "/a"; bm1.pinned = true; ctx.insert(bm1)
    let bm2 = Bookmark(); bm2.name = "B"; bm2.path = "/b"; bm2.pinned = false; ctx.insert(bm2)
    let bm3 = Bookmark(); bm3.name = "C"; bm3.path = "/c"; bm3.pinned = true; ctx.insert(bm3)
    try ctx.save()

    let andDesc = FetchDescriptor<Bookmark>(
        predicate: #Predicate { $0.pinned == true && $0.name == "C" }
    )
    let andResults = try ctx.fetch(andDesc)
    #expect(andResults.count == 1)
    #expect(andResults[0].name == "C")

    let orDesc = FetchDescriptor<Bookmark>(
        predicate: #Predicate { $0.name == "A" || $0.name == "B" }
    )
    let orResults = try ctx.fetch(orDesc)
    #expect(orResults.count == 2)
}

@Test func foundationPredicateContains() throws {
    let container = try ModelContainer(for: [Bookmark.self],
                                       configuration: ModelConfiguration(isStoredInMemoryOnly: true))
    let ctx = container.mainContext

    let bm1 = Bookmark(); bm1.name = "Hello World"; bm1.path = "/a"; bm1.pinned = false; ctx.insert(bm1)
    let bm2 = Bookmark(); bm2.name = "Goodbye"; bm2.path = "/b"; bm2.pinned = false; ctx.insert(bm2)
    try ctx.save()

    let descriptor = FetchDescriptor<Bookmark>(
        predicate: #Predicate { $0.name.contains("World") }
    )
    let results = try ctx.fetch(descriptor)
    #expect(results.count == 1)
    #expect(results[0].name == "Hello World")
}

@Test func foundationPredicateSpecialCharacters() throws {
    let container = try ModelContainer(for: [Bookmark.self],
                                       configuration: ModelConfiguration(isStoredInMemoryOnly: true))
    let ctx = container.mainContext

    let bm1 = Bookmark(); bm1.name = "It's a \"test\""; bm1.path = "/a"; bm1.pinned = false; ctx.insert(bm1)
    let bm2 = Bookmark(); bm2.name = "back\\slash"; bm2.path = "/b"; bm2.pinned = false; ctx.insert(bm2)
    let bm3 = Bookmark(); bm3.name = "normal"; bm3.path = "/c"; bm3.pinned = false; ctx.insert(bm3)
    try ctx.save()

    let desc1 = FetchDescriptor<Bookmark>(
        predicate: #Predicate { $0.name == "It's a \"test\"" }
    )
    let results1 = try ctx.fetch(desc1)
    #expect(results1.count == 1)

    let desc2 = FetchDescriptor<Bookmark>(
        predicate: #Predicate { $0.name == "back\\slash" }
    )
    let results2 = try ctx.fetch(desc2)
    #expect(results2.count == 1)
}
