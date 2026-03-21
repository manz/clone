import Testing
import Foundation
@testable import SwiftData

@Test func equalityPredicate() {
    let col = Column<Bookmark, String>("name")
    let pred = col == "test"
    #expect(pred.sql == "name = ?")
    #expect(pred.parameters == [.text("test")])
}

@Test func notEqualPredicate() {
    let col = Column<Bookmark, String>("name")
    let pred = col != "test"
    #expect(pred.sql == "name != ?")
    #expect(pred.parameters == [.text("test")])
}

@Test func comparisonPredicates() {
    let col = Column<Bookmark, Int>("count")
    #expect((col > 5).sql == "count > ?")
    #expect((col < 5).sql == "count < ?")
    #expect((col >= 5).sql == "count >= ?")
    #expect((col <= 5).sql == "count <= ?")
}

@Test func boolPredicate() {
    let col = Column<Bookmark, Bool>("pinned")
    let pred = col == true
    #expect(pred.sql == "pinned = ?")
    #expect(pred.parameters == [.integer(1)])
}

@Test func andCombinator() {
    let name = Column<Bookmark, String>("name")
    let pinned = Column<Bookmark, Bool>("pinned")
    let pred = (name == "test") && (pinned == true)
    #expect(pred.sql == "(name = ?) AND (pinned = ?)")
    #expect(pred.parameters == [.text("test"), .integer(1)])
}

@Test func orCombinator() {
    let name = Column<Bookmark, String>("name")
    let pred = (name == "a") || (name == "b")
    #expect(pred.sql == "(name = ?) OR (name = ?)")
    #expect(pred.parameters == [.text("a"), .text("b")])
}

@Test func notCombinator() {
    let pinned = Column<Bookmark, Bool>("pinned")
    let pred = !(pinned == true)
    #expect(pred.sql == "NOT (pinned = ?)")
}

@Test func stringContains() {
    let name = Column<Bookmark, String>("name")
    let pred = name.contains("foo")
    #expect(pred.sql == "name LIKE ?")
    #expect(pred.parameters == [.text("%foo%")])
}

@Test func stringHasPrefix() {
    let name = Column<Bookmark, String>("name")
    let pred = name.hasPrefix("/usr")
    #expect(pred.sql == "name LIKE ?")
    #expect(pred.parameters == [.text("/usr%")])
}

@Test func stringHasSuffix() {
    let name = Column<Bookmark, String>("name")
    let pred = name.hasSuffix(".txt")
    #expect(pred.sql == "name LIKE ?")
    #expect(pred.parameters == [.text("%.txt")])
}

@Test func complexPredicateEndToEnd() throws {
    let container = try ModelContainer(for: [Bookmark.self],
                                       configuration: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    for (name, path, pinned) in [
        ("Docs", "/docs", true),
        ("Projects", "/projects", true),
        ("Downloads", "/downloads", false),
        ("Temp", "/tmp", false),
    ] {
        let bm = Bookmark()
        bm.name = name
        bm.path = path
        bm.pinned = pinned
        context.insert(bm)
    }
    try context.save()

    let pinCol = Column<Bookmark, Bool>("pinned")
    let nameCol = Column<Bookmark, String>("name")
    let pred = (pinCol == true) && nameCol.hasPrefix("P")
    let results = try context.fetch(FetchDescriptor(predicate: pred))
    #expect(results.count == 1)
    #expect(results[0].name == "Projects")
}
