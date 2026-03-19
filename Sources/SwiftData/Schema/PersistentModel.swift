import Foundation

/// Protocol replacing Apple's @Model macro. Works on all platforms.
public protocol PersistentModel: AnyObject, Identifiable {
    var persistentModelID: PersistentIdentifier { get set }
    static var schema: ModelSchema { get }
    init()
}

extension PersistentModel {
    public var id: PersistentIdentifier { persistentModelID }
}
