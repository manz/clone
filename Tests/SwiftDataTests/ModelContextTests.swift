import Testing
import Foundation
@testable import SwiftData

// MARK: - Test Model

final class Bookmark: PersistentModel, PropertySettable {
    var persistentModelID = PersistentIdentifier()
    var name: String = ""
    var path: String = ""
    var pinned: Bool = false

    static let schema = ModelSchema(name: "Bookmark", properties: [
        PropertySchema(name: "name", type: .string),
        PropertySchema(name: "path", type: .string),
        PropertySchema(name: "pinned", type: .bool),
    ])

    required init() {}

    func setProperty(name: String, value: Any?) {
        switch name {
        case "name": self.name = value as? String ?? ""
        case "path": self.path = value as? String ?? ""
        case "pinned": self.pinned = value as? Bool ?? false
        default: break
        }
    }
}

// MARK: - Tests

@Test func insertAndFetch() throws {
    let container = try ModelContainer(for: [Bookmark.self],
                                       configuration: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    let bm = Bookmark()
    bm.name = "Projects"
    bm.path = "/Users/manz/Projects"
    bm.pinned = true

    context.insert(bm)
    try context.save()

    let results = try context.fetchAll(Bookmark.self)
    #expect(results.count == 1)
    #expect(results[0].name == "Projects")
    #expect(results[0].path == "/Users/manz/Projects")
    #expect(results[0].pinned == true)
}

@Test func fetchWithPredicate() throws {
    let container = try ModelContainer(for: [Bookmark.self],
                                       configuration: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    for (name, pinned) in [("Alpha", false), ("Beta", true), ("Gamma", true)] {
        let bm = Bookmark()
        bm.name = name
        bm.path = "/tmp/\(name)"
        bm.pinned = pinned
        context.insert(bm)
    }
    try context.save()

    let pinnedCol = Column<Bookmark, Bool>("pinned")
    let descriptor = FetchDescriptor<Bookmark>(
        sqlPredicate: pinnedCol == true,
        sortBy: [SortDescriptor("name")]
    )
    let results = try context.fetch(descriptor)
    #expect(results.count == 2)
    #expect(results[0].name == "Beta")
    #expect(results[1].name == "Gamma")
}

@Test func deleteModel() throws {
    let container = try ModelContainer(for: [Bookmark.self],
                                       configuration: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    let bm = Bookmark()
    bm.name = "ToDelete"
    bm.path = "/tmp"
    context.insert(bm)
    try context.save()

    let fetched = try context.fetchAll(Bookmark.self)
    #expect(fetched.count == 1)

    context.delete(fetched[0])
    try context.save()

    let afterDelete = try context.fetchAll(Bookmark.self)
    #expect(afterDelete.count == 0)
}

@Test func fetchWithSortAndLimit() throws {
    let container = try ModelContainer(for: [Bookmark.self],
                                       configuration: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    for name in ["Charlie", "Alpha", "Delta", "Beta"] {
        let bm = Bookmark()
        bm.name = name
        bm.path = "/\(name)"
        context.insert(bm)
    }
    try context.save()

    let descriptor = FetchDescriptor<Bookmark>(
        sortBy: [SortDescriptor("name")],
        limit: 2
    )
    let results = try context.fetch(descriptor)
    #expect(results.count == 2)
    #expect(results[0].name == "Alpha")
    #expect(results[1].name == "Beta")
}

@Test func fetchCount() throws {
    let container = try ModelContainer(for: [Bookmark.self],
                                       configuration: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    for i in 0..<3 {
        let bm = Bookmark()
        bm.name = "Item \(i)"
        bm.path = "/\(i)"
        context.insert(bm)
    }
    try context.save()

    let count = try context.fetchCount(FetchDescriptor<Bookmark>())
    #expect(count == 3)
}

@Test func updateViaInsertOrReplace() throws {
    let container = try ModelContainer(for: [Bookmark.self],
                                       configuration: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    let bm = Bookmark()
    bm.name = "Original"
    bm.path = "/orig"
    context.insert(bm)
    try context.save()

    bm.name = "Updated"
    context.insert(bm)
    try context.save()

    let results = try context.fetchAll(Bookmark.self)
    #expect(results.count == 1)
    #expect(results[0].name == "Updated")
}

@Test func saveGenerationIncrementsOnSave() throws {
    let container = try ModelContainer(for: [Bookmark.self],
                                       configuration: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext
    #expect(context.generation == 0)

    let bm = Bookmark()
    bm.name = "Test"
    bm.path = "/"
    context.insert(bm)
    try context.save()
    #expect(context.generation == 1)

    try context.save()
    #expect(context.generation == 2)
}
