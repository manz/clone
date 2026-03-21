// Aquax SDK: Charts
// Matches Apple's Swift Charts API surface for compilation.
import SwiftUI

// MARK: - Chart

public struct Chart<Content>: View {
    public init(@ChartContentBuilder content: () -> Content) {}
    public var body: some View { EmptyView() }
}

// MARK: - ChartContentBuilder

@resultBuilder
public struct ChartContentBuilder {
    public static func buildBlock<C>(_ content: C) -> C { content }
    public static func buildBlock() -> EmptyChartContent { EmptyChartContent() }
    public static func buildBlock<C0, C1>(_ c0: C0, _ c1: C1) -> ChartTupleContent<(C0, C1)> { ChartTupleContent() }
    public static func buildBlock<C0, C1, C2>(_ c0: C0, _ c1: C1, _ c2: C2) -> ChartTupleContent<(C0, C1, C2)> { ChartTupleContent() }
    public static func buildBlock<C0, C1, C2, C3>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> ChartTupleContent<(C0, C1, C2, C3)> { ChartTupleContent() }
    public static func buildBlock<C0, C1, C2, C3, C4>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4) -> ChartTupleContent<(C0, C1, C2, C3, C4)> { ChartTupleContent() }
    public static func buildOptional<C>(_ content: C?) -> C? { content }
    public static func buildEither<T, F>(first content: T) -> ChartEither<T, F> { .first(content) }
    public static func buildEither<T, F>(second content: F) -> ChartEither<T, F> { .second(content) }
    public static func buildExpression(_ expression: Never) -> Never {}
    public static func buildBlock(_ n: Never) -> Never {}
    public static func buildArray<C>(_ components: [C]) -> [C] { components }
}

public struct EmptyChartContent {}
public struct ChartTupleContent<T> {}
public enum ChartEither<T, F> { case first(T), second(F) }

// MARK: - Mark Types

public struct BarMark {
    public init(x: PlottableValue<String>? = nil, y: PlottableValue<Double>? = nil) {}
    public init(x: PlottableValue<Double>? = nil, y: PlottableValue<String>? = nil) {}
    public init(x: PlottableValue<Int>? = nil, y: PlottableValue<Double>? = nil) {}
    public func foregroundStyle(by value: PlottableValue<String>) -> BarMark { self }
    public func foregroundStyle(_ color: Color) -> BarMark { self }
    public func cornerRadius(_ radius: CGFloat) -> BarMark { self }
    public func annotation<Content: View>(position: AnnotationPosition = .automatic, @ViewBuilder content: () -> Content) -> BarMark { self }
}

public struct LineMark {
    public init(x: PlottableValue<String>? = nil, y: PlottableValue<Double>? = nil) {}
    public init(x: PlottableValue<Double>? = nil, y: PlottableValue<Double>? = nil) {}
    public func foregroundStyle(_ color: Color) -> LineMark { self }
    public func interpolationMethod(_ method: InterpolationMethod) -> LineMark { self }
}

public struct AreaMark {
    public init(x: PlottableValue<String>? = nil, y: PlottableValue<Double>? = nil) {}
    public func foregroundStyle(_ color: Color) -> AreaMark { self }
}

public struct PointMark {
    public init(x: PlottableValue<String>? = nil, y: PlottableValue<Double>? = nil) {}
    public func foregroundStyle(_ color: Color) -> PointMark { self }
}

public struct RuleMark {
    public init(y: PlottableValue<Double>? = nil) {}
    public init(x: PlottableValue<Double>? = nil) {}
    public func foregroundStyle(_ color: Color) -> RuleMark { self }
}

public enum AnnotationPosition { case automatic, top, bottom, leading, trailing, overlay }
public enum InterpolationMethod { case linear, cardinal, catmullRom, monotone, stepStart, stepCenter, stepEnd }

// MARK: - PlottableValue

public struct PlottableValue<T> {
    public static func value(_ label: String, _ value: T) -> PlottableValue { PlottableValue() }
}

// MARK: - Axis

public struct AxisMarks<Content> {
    public init(values: AxisMarkValues = .automatic, @ChartContentBuilder content: @escaping (AxisValue) -> Content) {}
    public init(position: AxisMarkPosition = .automatic, values: AxisMarkValues = .automatic, @ChartContentBuilder content: @escaping (AxisValue) -> Content) {}
}
extension AxisMarks where Content == Never {
    public init(values: AxisMarkValues = .automatic) {}
    public init(position: AxisMarkPosition = .automatic, values: AxisMarkValues = .automatic) {}
}

public enum AxisMarkPosition { case automatic, leading, trailing, top, bottom }

public struct AxisMarkValues: Sendable {
    public static let automatic = AxisMarkValues()
    public static func automatic(desiredCount: Int? = nil, roundLowerBound: Bool = true, roundUpperBound: Bool = true) -> AxisMarkValues { AxisMarkValues() }
    public static func stride(by value: Int) -> AxisMarkValues { AxisMarkValues() }
    public static func stride(by value: Double) -> AxisMarkValues { AxisMarkValues() }
}

public struct AxisValue {
    public var index: Int { 0 }
    public func as_<T>(_ type: T.Type) -> T? { nil }
}

public struct AxisValueLabel<Content: View>: View {
    public var body: some View { EmptyView() }
}
extension AxisValueLabel where Content == Text {
    public init() {}
    public init(_ label: String) {}
}
extension AxisValueLabel {
    public init(@ViewBuilder content: () -> Content) {}
}

public struct AxisGridLine: View {
    public init() {}
    public init(stroke: StrokeStyle) {}
    public func foregroundStyle(_ color: Color) -> AxisGridLine { self }
    public var body: some View { EmptyView() }
}

public struct AxisTick: View {
    public init() {}
    public init(stroke: StrokeStyle) {}
    public var body: some View { EmptyView() }
}

// MARK: - Chart Domain

public struct ChartDomain {
    public static func automatic(includesZero: Bool = false) -> ChartDomain { ChartDomain() }
}

// MARK: - Chart Modifiers

extension Chart {
    public func chartXAxis(@ChartContentBuilder content: () -> some Any) -> Chart { self }
    public func chartYAxis(@ChartContentBuilder content: () -> some Any) -> Chart { self }
    public func chartXScale(domain: ChartDomain) -> Chart { self }
    public func chartYScale(domain: ChartDomain) -> Chart { self }
    public func chartForegroundStyleScale(_ mapping: [String: Color]) -> Chart { self }
    public func chartForegroundStyleScale<S>(_ scale: S) -> Chart { self }
    public func chartLegend(_ visibility: Visibility) -> Chart { self }
    public func chartLegend(position: Any? = nil) -> Chart { self }
    public func chartPlotStyle<S: View>(@ViewBuilder content: (ChartPlotContent) -> S) -> Chart { self }
}

public struct ChartPlotContent: View {
    public var body: some View { EmptyView() }
    public func frame(height: CGFloat) -> ChartPlotContent { self }
}
