import Foundation

/// A control for selecting a value from a bounded range.
/// Matches Apple's SwiftUI `Slider` struct.
public struct Slider: _PrimitiveView {
    let child: ViewNode

    public init(value: Binding<Double>, in range: ClosedRange<Double> = 0...1, step: Double? = nil) {
        let cgRange = CGFloat(range.lowerBound)...CGFloat(range.upperBound)
        self.child = .slider(value: CGFloat(value.wrappedValue), range: cgRange, label: .empty)
    }

    public init(value: Binding<CGFloat>, in range: ClosedRange<CGFloat> = 0...1) {
        self.child = .slider(value: value.wrappedValue, range: range, label: .empty)
    }

    public init<V: BinaryFloatingPoint>(value: Binding<V>, in range: ClosedRange<V> = 0...1) {
        let cgRange = CGFloat(range.lowerBound)...CGFloat(range.upperBound)
        self.child = .slider(value: CGFloat(value.wrappedValue), range: cgRange, label: .empty)
    }

    public init(value: Binding<Double>, in range: ClosedRange<Double> = 0...1, step: Double? = nil, @ViewBuilder label: () -> some View) {
        let cgRange = CGFloat(range.lowerBound)...CGFloat(range.upperBound)
        let labelNode = _flattenToNodes(label())
        self.child = .slider(value: CGFloat(value.wrappedValue), range: cgRange, label: labelNode.count == 1 ? labelNode[0] : .empty)
    }

    public init(value: Binding<Double>, in range: ClosedRange<Double> = 0...1, step: Double? = nil, @ViewBuilder label: () -> some View, @ViewBuilder minimumValueLabel: () -> some View, @ViewBuilder maximumValueLabel: () -> some View) {
        let cgRange = CGFloat(range.lowerBound)...CGFloat(range.upperBound)
        self.child = .slider(value: CGFloat(value.wrappedValue), range: cgRange, label: .empty)
    }

    /// `Slider(value:in:onEditingChanged:)` — with editing callback.
    public init(value: Binding<Double>, in range: ClosedRange<Double> = 0...1, onEditingChanged: @escaping (Bool) -> Void) {
        let cgRange = CGFloat(range.lowerBound)...CGFloat(range.upperBound)
        self.child = .slider(value: CGFloat(value.wrappedValue), range: cgRange, label: .empty)
    }

    /// `Slider(value:in:step:onEditingChanged:)` — with step and editing callback.
    public init(value: Binding<Double>, in range: ClosedRange<Double> = 0...1, step: Double? = nil, onEditingChanged: @escaping (Bool) -> Void) {
        let cgRange = CGFloat(range.lowerBound)...CGFloat(range.upperBound)
        self.child = .slider(value: CGFloat(value.wrappedValue), range: cgRange, label: .empty)
    }

    /// Generic `Slider(value:in:onEditingChanged:)`.
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in range: ClosedRange<V> = 0...1, onEditingChanged: @escaping (Bool) -> Void) {
        let cgRange = CGFloat(range.lowerBound)...CGFloat(range.upperBound)
        self.child = .slider(value: CGFloat(value.wrappedValue), range: cgRange, label: .empty)
    }

    public var _nodeRepresentation: ViewNode {
        child
    }
}
