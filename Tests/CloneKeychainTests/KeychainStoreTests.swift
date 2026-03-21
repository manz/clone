import Testing
import Foundation
@testable import CloneKeychain
import CloneProtocol

// MARK: - KeychainStore CRUD tests (in-memory SQLite)

@Test func addAndSearchItem() throws {
    let store = KeychainStore(path: ":memory:")

    let item = KeychainItem(
        itemClass: .genericPassword,
        service: "TestService",
        account: "testuser",
        valueData: "secret123".data(using: .utf8),
        appId: "com.test.app"
    )

    let addResult = store.add(item)
    #expect(addResult == .success)

    let query = KeychainSearchQuery(
        itemClass: .genericPassword,
        service: "TestService",
        account: "testuser"
    )
    let response = store.search(query)

    guard case .item(let found) = response else {
        Issue.record("Expected .item, got \(response)")
        return
    }
    #expect(found.service == "TestService")
    #expect(found.account == "testuser")
    #expect(found.valueData == "secret123".data(using: .utf8))
}

@Test func duplicateItemReturnsError() throws {
    let store = KeychainStore(path: ":memory:")

    let item = KeychainItem(
        itemClass: .genericPassword,
        service: "Dup",
        account: "user",
        appId: "com.test"
    )

    #expect(store.add(item) == .success)
    #expect(store.add(item) == .duplicateItem)
}

@Test func searchNonExistentReturnsNotFound() throws {
    let store = KeychainStore(path: ":memory:")

    let query = KeychainSearchQuery(
        itemClass: .genericPassword,
        service: "NonExistent"
    )
    let response = store.search(query)

    guard case .error(let code) = response else {
        Issue.record("Expected .error, got \(response)")
        return
    }
    #expect(code == .itemNotFound)
}

@Test func updateItem() throws {
    let store = KeychainStore(path: ":memory:")

    let item = KeychainItem(
        itemClass: .genericPassword,
        service: "UpdateMe",
        account: "user",
        valueData: "old".data(using: .utf8),
        appId: "com.test"
    )
    #expect(store.add(item) == .success)

    let query = KeychainSearchQuery(service: "UpdateMe", account: "user")
    let updated = KeychainItem(
        itemClass: .genericPassword,
        valueData: "new".data(using: .utf8),
        appId: "com.test"
    )
    #expect(store.update(query: query, attributes: updated) == .success)

    let response = store.search(query)
    guard case .item(let found) = response else {
        Issue.record("Expected .item after update")
        return
    }
    #expect(found.valueData == "new".data(using: .utf8))
}

@Test func deleteItem() throws {
    let store = KeychainStore(path: ":memory:")

    let item = KeychainItem(
        itemClass: .genericPassword,
        service: "DeleteMe",
        account: "user",
        appId: "com.test"
    )
    #expect(store.add(item) == .success)

    let query = KeychainSearchQuery(service: "DeleteMe", account: "user")
    #expect(store.delete(query) == .success)

    let response = store.search(query)
    guard case .error(let code) = response else {
        Issue.record("Expected .error after delete")
        return
    }
    #expect(code == .itemNotFound)
}

@Test func searchAllReturnsMultipleItems() throws {
    let store = KeychainStore(path: ":memory:")

    for i in 0..<3 {
        let item = KeychainItem(
            itemClass: .genericPassword,
            service: "Multi",
            account: "user\(i)",
            appId: "com.test"
        )
        #expect(store.add(item) == .success)
    }

    let query = KeychainSearchQuery(
        service: "Multi",
        matchLimit: .all
    )
    let response = store.search(query)

    guard case .items(let found) = response else {
        Issue.record("Expected .items, got \(response)")
        return
    }
    #expect(found.count == 3)
}

@Test func searchByClassFilters() throws {
    let store = KeychainStore(path: ":memory:")

    let password = KeychainItem(
        itemClass: .genericPassword,
        service: "FilterTest",
        account: "user",
        appId: "com.test"
    )
    let wifi = KeychainItem(
        itemClass: .internetPassword,
        service: "FilterTest",
        account: "wifi",
        appId: "com.test"
    )
    #expect(store.add(password) == .success)
    #expect(store.add(wifi) == .success)

    let query = KeychainSearchQuery(
        itemClass: .genericPassword,
        service: "FilterTest",
        matchLimit: .all
    )
    let response = store.search(query)

    guard case .items(let found) = response else {
        guard case .item = response else {
            Issue.record("Expected items or item")
            return
        }
        return
    }
    #expect(found.count == 1)
    #expect(found[0].account == "user")
}

// MARK: - Protocol encoding tests

@Test func keychainRequestRoundTrips() throws {
    let item = KeychainItem(
        itemClass: .genericPassword,
        service: "Test",
        account: "user",
        appId: "com.test"
    )
    let requests: [KeychainRequest] = [
        .add(item),
        .search(KeychainSearchQuery(service: "Test")),
        .delete(KeychainSearchQuery(service: "Test")),
    ]
    for request in requests {
        let data = try WireProtocol.encode(request)
        let result = WireProtocol.decode(KeychainRequest.self, from: data)
        #expect(result != nil)
    }
}

@Test func keychainResponseRoundTrips() throws {
    let item = KeychainItem(
        itemClass: .genericPassword,
        service: "Test",
        appId: "com.test"
    )
    let responses: [KeychainResponse] = [
        .success,
        .item(item),
        .items([item]),
        .error(.itemNotFound),
    ]
    for response in responses {
        let data = try WireProtocol.encode(response)
        let result = WireProtocol.decode(KeychainResponse.self, from: data)
        #expect(result != nil)
    }
}
