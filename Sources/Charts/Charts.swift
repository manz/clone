// Aquax SDK stub: Charts
// Empty chart views for compilation.
import SwiftUI

public struct Chart<Content>: View {
    public init(@ChartContentBuilder content: () -> Content) {}
    public var body: some View { EmptyView() }
}

@resultBuilder
public struct ChartContentBuilder {
    public static func buildBlock<C>(_ content: C) -> C { content }
    public static func buildBlock() -> EmptyChartContent { EmptyChartContent() }
    public static func buildOptional<C>(_ content: C?) -> C? { content }
    public static func buildEither<T, F>(first content: T) -> ChartEither<T, F> { .first(content) }
    public static func buildEither<T, F>(second content: F) -> ChartEither<T, F> { .second(content) }
}

public struct EmptyChartContent {}
public enum ChartEither<T, F> { case first(T), second(F) }

public struct BarMark {
    public init(x: PlottableValue<String>? = nil, y: PlottableValue<Double>? = nil) {}
    public init(x: PlottableValue<Double>? = nil, y: PlottableValue<String>? = nil) {}
    public func foregroundStyle(by value: PlottableValue<String>) -> BarMark { self }
}

public struct LineMark {
    public init(x: PlottableValue<String>? = nil, y: PlottableValue<Double>? = nil) {}
    public init(x: PlottableValue<Double>? = nil, y: PlottableValue<Double>? = nil) {}
}

public struct AreaMark {
    public init(x: PlottableValue<String>? = nil, y: PlottableValue<Double>? = nil) {}
}

public struct PointMark {
    public init(x: PlottableValue<String>? = nil, y: PlottableValue<Double>? = nil) {}
}

public struct RuleMark {
    public init(y: PlottableValue<Double>? = nil) {}
    public init(x: PlottableValue<Double>? = nil) {}
}

public struct PlottableValue<T> {
    public static func value(_ label: String, _ value: T) -> PlottableValue { PlottableValue() }
}

public struct AxisMarks<Content> {
    public init(values: Any? = nil, @ChartContentBuilder content: @escaping (AxisValue) -> Content) {}
}
extension AxisMarks where Content == Never {
    public init(values: Any? = nil) { fatalError() }
}

public struct AxisValue {
    public var index: Int { 0 }
    public func as_<T>(_ type: T.Type) -> T? { nil }
}

public struct AxisValueLabel<Content> {}
extension AxisValueLabel where Content == Never {
    public init() {}
}

public struct AxisGridLine {
    public init() {}
}

extension Chart {
    public func chartXAxis(@ViewBuilder content: () -> some View) -> Chart { self }
    public func chartYAxis(@ViewBuilder content: () -> some View) -> Chart { self }
    public func chartXScale(domain: Any? = nil) -> Chart { self }
    public func chartYScale(domain: Any? = nil) -> Chart { self }
}
