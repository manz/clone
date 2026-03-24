import Foundation

// MARK: - Item Class
nonisolated(unsafe) public let kSecClass = "class" as NSString
nonisolated(unsafe) public let kSecClassInternetPassword = "inet" as NSString
nonisolated(unsafe) public let kSecClassGenericPassword = "genp" as NSString
nonisolated(unsafe) public let kSecClassCertificate = "cert" as NSString
nonisolated(unsafe) public let kSecClassKey = "keys" as NSString
nonisolated(unsafe) public let kSecClassIdentity = "idnt" as NSString

// MARK: - Attributes
nonisolated(unsafe) public let kSecAttrService = "svce" as NSString
nonisolated(unsafe) public let kSecAttrAccount = "acct" as NSString
nonisolated(unsafe) public let kSecAttrServer = "srvr" as NSString
nonisolated(unsafe) public let kSecAttrLabel = "labl" as NSString
nonisolated(unsafe) public let kSecAttrAccessGroup = "agrp" as NSString
nonisolated(unsafe) public let kSecAttrCreationDate = "cdat" as NSString
nonisolated(unsafe) public let kSecAttrModificationDate = "mdat" as NSString

// MARK: - Value
nonisolated(unsafe) public let kSecValueData = "v_Data" as NSString

// MARK: - Return types
nonisolated(unsafe) public let kSecReturnData = "r_Data" as NSString
nonisolated(unsafe) public let kSecReturnAttributes = "r_Attributes" as NSString
nonisolated(unsafe) public let kSecReturnRef = "r_Ref" as NSString

// MARK: - Match
nonisolated(unsafe) public let kSecMatchLimit = "m_Limit" as NSString
nonisolated(unsafe) public let kSecMatchLimitOne = "m_LimitOne" as NSString
nonisolated(unsafe) public let kSecMatchLimitAll = "m_LimitAll" as NSString
