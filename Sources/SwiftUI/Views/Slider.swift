import Foundation

/// A control for selecting a value from a bounded range.
/// Matches Apple's SwiftUI `Slider` struct.
public struct Slider: View {
    let child: ViewNode

    public init(value: Binding<CGFloat>, in range: ClosedRange<CGFloat> = 0...1) {
        self.child = .slider(value: value.wrappedValue, range: range, label: .empty)
    }

    public var body: ViewNode {
        child
    }
}
