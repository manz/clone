import Foundation

/// Shared keychain client (lazy connect).
private let sharedClient = KeychainClient()

// MARK: - SecItem Functions

/// Add an item to the keychain.
@discardableResult
public func SecItemAdd(_ attributes: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
    let dict = attributes as! [String: Any]
    guard let item = keychainItemFromDict(dict) else { return errSecParam }

    let response = sharedClient.send(.add(item))
    switch response {
    case .success: return errSecSuccess
    case .error(let code): return code.rawValue
    default: return errSecParam
    }
}

/// Search for keychain items.
@discardableResult
public func SecItemCopyMatching(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
    let dict = query as! [String: Any]
    let searchQuery = searchQueryFromDict(dict)

    let response = sharedClient.send(.search(searchQuery))
    switch response {
    case .item(let item):
        if let result = result {
            if dict[kSecReturnData as String] as? Bool == true, let data = item.valueData {
                result.pointee = data as CFTypeRef
            } else {
                result.pointee = dictFromKeychainItem(item) as CFTypeRef
            }
        }
        return errSecSuccess
    case .items(let items):
        if let result = result {
            let dicts = items.map { dictFromKeychainItem($0) }
            result.pointee = dicts as CFTypeRef
        }
        return errSecSuccess
    case .error(let code):
        return code.rawValue
    default:
        return errSecParam
    }
}

/// Update keychain items matching the query.
@discardableResult
public func SecItemUpdate(_ query: CFDictionary, _ attributesToUpdate: CFDictionary) -> OSStatus {
    let queryDict = query as! [String: Any]
    let updateDict = attributesToUpdate as! [String: Any]
    let searchQuery = searchQueryFromDict(queryDict)
    guard let updateItem = keychainItemFromDict(updateDict, partial: true) else { return errSecParam }

    let response = sharedClient.send(.update(query: searchQuery, attributes: updateItem))
    switch response {
    case .success: return errSecSuccess
    case .error(let code): return code.rawValue
    default: return errSecParam
    }
}

/// Delete keychain items matching the query.
@discardableResult
public func SecItemDelete(_ query: CFDictionary) -> OSStatus {
    let dict = query as! [String: Any]
    let searchQuery = searchQueryFromDict(dict)

    let response = sharedClient.send(.delete(searchQuery))
    switch response {
    case .success: return errSecSuccess
    case .error(let code): return code.rawValue
    default: return errSecParam
    }
}

// MARK: - Dictionary Conversion Helpers

private func itemClassFromString(_ str: String) -> SecItemClass? {
    if str == (kSecClassInternetPassword as String) { return .internetPassword }
    if str == (kSecClassGenericPassword as String) { return .genericPassword }
    if str == (kSecClassCertificate as String) { return .certificate }
    if str == (kSecClassKey as String) { return .key }
    if str == (kSecClassIdentity as String) { return .identity }
    return nil
}

private func keychainItemFromDict(_ dict: [String: Any], partial: Bool = false) -> KeychainItem? {
    let itemClass: SecItemClass
    if let classStr = dict[kSecClass as String] as? String, let cls = itemClassFromString(classStr) {
        itemClass = cls
    } else if partial {
        itemClass = .genericPassword  // placeholder for partial updates
    } else {
        return nil
    }

    let appId = ProcessInfo.processInfo.processName

    return KeychainItem(
        itemClass: itemClass,
        service: dict[kSecAttrService as String] as? String,
        account: dict[kSecAttrAccount as String] as? String,
        server: dict[kSecAttrServer as String] as? String,
        label: dict[kSecAttrLabel as String] as? String,
        valueData: dict[kSecValueData as String] as? Data,
        accessGroup: dict[kSecAttrAccessGroup as String] as? String,
        appId: appId
    )
}

private func searchQueryFromDict(_ dict: [String: Any]) -> KeychainSearchQuery {
    let itemClass: SecItemClass?
    if let classStr = dict[kSecClass as String] as? String {
        itemClass = itemClassFromString(classStr)
    } else {
        itemClass = nil
    }

    let matchLimit: KeychainSearchQuery.MatchLimit
    if let limit = dict[kSecMatchLimit as String] as? String, limit == (kSecMatchLimitAll as String) {
        matchLimit = .all
    } else {
        matchLimit = .one
    }

    return KeychainSearchQuery(
        itemClass: itemClass,
        service: dict[kSecAttrService as String] as? String,
        account: dict[kSecAttrAccount as String] as? String,
        server: dict[kSecAttrServer as String] as? String,
        matchLimit: matchLimit,
        returnData: dict[kSecReturnData as String] as? Bool ?? false
    )
}

private func dictFromKeychainItem(_ item: KeychainItem) -> [String: Any] {
    var dict: [String: Any] = [:]
    dict[kSecAttrService as String] = item.service
    dict[kSecAttrAccount as String] = item.account
    dict[kSecAttrServer as String] = item.server
    dict[kSecAttrLabel as String] = item.label
    if let data = item.valueData {
        dict[kSecValueData as String] = data
    }
    dict[kSecAttrCreationDate as String] = item.creationDate
    dict[kSecAttrModificationDate as String] = item.modificationDate
    return dict
}
