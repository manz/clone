import Foundation

/// Button role — matches Apple's SwiftUI ButtonRole.
public struct ButtonRole: Equatable, Sendable {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let destructive = ButtonRole("destructive")
    public static let cancel = ButtonRole("cancel")
}
