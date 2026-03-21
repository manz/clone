import Foundation

// MARK: - Item Class
nonisolated(unsafe) public let kSecClass = "class" as CFString
nonisolated(unsafe) public let kSecClassInternetPassword = "inet" as CFString
nonisolated(unsafe) public let kSecClassGenericPassword = "genp" as CFString
nonisolated(unsafe) public let kSecClassCertificate = "cert" as CFString
nonisolated(unsafe) public let kSecClassKey = "keys" as CFString
nonisolated(unsafe) public let kSecClassIdentity = "idnt" as CFString

// MARK: - Attributes
nonisolated(unsafe) public let kSecAttrService = "svce" as CFString
nonisolated(unsafe) public let kSecAttrAccount = "acct" as CFString
nonisolated(unsafe) public let kSecAttrServer = "srvr" as CFString
nonisolated(unsafe) public let kSecAttrLabel = "labl" as CFString
nonisolated(unsafe) public let kSecAttrAccessGroup = "agrp" as CFString
nonisolated(unsafe) public let kSecAttrCreationDate = "cdat" as CFString
nonisolated(unsafe) public let kSecAttrModificationDate = "mdat" as CFString

// MARK: - Value
nonisolated(unsafe) public let kSecValueData = "v_Data" as CFString

// MARK: - Return types
nonisolated(unsafe) public let kSecReturnData = "r_Data" as CFString
nonisolated(unsafe) public let kSecReturnAttributes = "r_Attributes" as CFString
nonisolated(unsafe) public let kSecReturnRef = "r_Ref" as CFString

// MARK: - Match
nonisolated(unsafe) public let kSecMatchLimit = "m_Limit" as CFString
nonisolated(unsafe) public let kSecMatchLimitOne = "m_LimitOne" as CFString
nonisolated(unsafe) public let kSecMatchLimitAll = "m_LimitAll" as CFString
