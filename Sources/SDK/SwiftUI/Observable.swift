import Foundation

/// `@Observable` shim for Clone/Aquax.
///
/// On real macOS 14+, `@Observable` is a macro from the Observation framework
/// that synthesizes property tracking. On Clone, the frame loop rebuilds the
/// entire view tree every frame, so observation tracking is unnecessary.
/// This protocol exists for API compatibility — classes conform to it and
/// SwiftUI code that checks `Observable` conformance works on both platforms.
public protocol Observable: AnyObject {}
