import Testing
import Foundation
@testable import KeychainServices

// MARK: - SecConstants tests

@Test func secClassConstantsExist() {
    #expect((KeychainServices.kSecClass as String) == "class")
    #expect((KeychainServices.kSecClassGenericPassword as String) == "genp")
    #expect((KeychainServices.kSecClassInternetPassword as String) == "inet")
    #expect((KeychainServices.kSecAttrService as String) == "svce")
    #expect((KeychainServices.kSecAttrAccount as String) == "acct")
    #expect((KeychainServices.kSecValueData as String) == "v_Data")
    #expect((KeychainServices.kSecReturnData as String) == "r_Data")
    #expect((KeychainServices.kSecMatchLimit as String) == "m_Limit")
    #expect((KeychainServices.kSecMatchLimitAll as String) == "m_LimitAll")
    #expect((KeychainServices.kSecMatchLimitOne as String) == "m_LimitOne")
}

@Test func osStatusConstantsMatch() {
    #expect(KeychainServices.errSecSuccess == 0)
    #expect(KeychainServices.errSecItemNotFound == -25300)
    #expect(KeychainServices.errSecDuplicateItem == -25299)
    #expect(KeychainServices.errSecAuthFailed == -25293)
    #expect(KeychainServices.errSecParam == -50)
}

@Test func errorCodeRawValues() {
    #expect(KeychainErrorCode.success.rawValue == KeychainServices.errSecSuccess)
    #expect(KeychainErrorCode.itemNotFound.rawValue == KeychainServices.errSecItemNotFound)
    #expect(KeychainErrorCode.duplicateItem.rawValue == KeychainServices.errSecDuplicateItem)
}
