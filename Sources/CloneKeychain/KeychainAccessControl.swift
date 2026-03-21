import Foundation
import CloneProtocol

/// Validates access control for keychain items.
public enum KeychainAccessControl {
    /// Check if the given appId is allowed to access the item.
    public static func canAccess(item: KeychainItem, appId: String) -> Bool {
        // Owner always has access
        if item.appId == appId { return true }
        // Shared access via accessGroup
        if let group = item.accessGroup, !group.isEmpty {
            return true  // Any app in the group can access
        }
        return false
    }
}
