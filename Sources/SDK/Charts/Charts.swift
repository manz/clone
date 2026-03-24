// Aquax SDK: Charts
// Matches Apple's Swift Charts API surface for compilation.
import SwiftUI

// MARK: - Plottable Protocol

public protocol Plottable {
    associatedtype PrimitivePlottable
    var primitivePlottable: PrimitivePlottable { get }
    init?(primitivePlottable: PrimitivePlottable)
}

extension String: Plottable {
    public var primitivePlottable: String { self }
    public init?(primitivePlottable: String) { self = primitivePlottable }
}

extension Int: Plottable {
    public var primitivePlottable: Int { self }
    public init?(primitivePlottable: Int) { self = primitivePlottable }
}

extension Double: Plottable {
    public var primitivePlottable: Double { self }
    public init?(primitivePlottable: Double) { self = primitivePlottable }
}

extension Float: Plottable {
    public var primitivePlottable: Float { self }
    public init?(primitivePlottable: Float) { self = primitivePlottable }
}

extension Date: Plottable {
    public var primitivePlottable: Date { self }
    public init?(primitivePlottable: Date) { self = primitivePlottable }
}

// MARK: - ChartContent Protocol

public protocol ChartContent: View {}

// MARK: - PlottableValue

public struct PlottableValue<T: Plottable> {
    public static func value(_ label: String, _ value: T) -> PlottableValue { PlottableValue() }
    public static func value(_ label: String, _ value: T, unit: Calendar.Component) -> PlottableValue { PlottableValue() }
}

// MARK: - MarkDimension

public struct MarkDimension: Sendable {
    public static let automatic = MarkDimension()
    public static func fixed(_ value: CGFloat) -> MarkDimension { MarkDimension() }
    public static func ratio(_ ratio: CGFloat) -> MarkDimension { MarkDimension() }
    public static func inset(_ inset: CGFloat) -> MarkDimension { MarkDimension() }
}

// MARK: - MarkStackingMethod

public enum MarkStackingMethod {
    case standard
    case normalized
    case center
    case unstacked
}

// MARK: - Chart

public struct Chart<Content>: View {
    public init(@ChartContentBuilder content: () -> Content) {}
    public init<Data: RandomAccessCollection>(_ data: Data, @ChartContentBuilder content: @escaping (Data.Element) -> Content) {}
    public init<Data: RandomAccessCollection, ID: Hashable>(_ data: Data, id: KeyPath<Data.Element, ID>, @ChartContentBuilder content: @escaping (Data.Element) -> Content) {}
    public var body: some View { EmptyView() }
}

// MARK: - ChartContentBuilder

@resultBuilder
public struct ChartContentBuilder {
    public static func buildExpression<C>(_ expression: C) -> C { expression }
    public static func buildExpression<D, ID: Hashable, Content: View>(_ expression: ForEach<D, ID, Content>) -> ForEach<D, ID, Content> { expression }
    public static func buildBlock<C>(_ content: C) -> C { content }
    public static func buildBlock() -> EmptyChartContent { EmptyChartContent() }
    public static func buildBlock<C0, C1>(_ c0: C0, _ c1: C1) -> ChartTupleContent<(C0, C1)> { ChartTupleContent() }
    public static func buildBlock<C0, C1, C2>(_ c0: C0, _ c1: C1, _ c2: C2) -> ChartTupleContent<(C0, C1, C2)> { ChartTupleContent() }
    public static func buildBlock<C0, C1, C2, C3>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> ChartTupleContent<(C0, C1, C2, C3)> { ChartTupleContent() }
    public static func buildBlock<C0, C1, C2, C3, C4>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4) -> ChartTupleContent<(C0, C1, C2, C3, C4)> { ChartTupleContent() }
    public static func buildBlock<C0, C1, C2, C3, C4, C5>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5) -> ChartTupleContent<(C0, C1, C2, C3, C4, C5)> { ChartTupleContent() }
    public static func buildBlock<C0, C1, C2, C3, C4, C5, C6>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6) -> ChartTupleContent<(C0, C1, C2, C3, C4, C5, C6)> { ChartTupleContent() }
    public static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7) -> ChartTupleContent<(C0, C1, C2, C3, C4, C5, C6, C7)> { ChartTupleContent() }
    public static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7, C8>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8) -> ChartTupleContent<(C0, C1, C2, C3, C4, C5, C6, C7, C8)> { ChartTupleContent() }
    public static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7, C8, C9>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9) -> ChartTupleContent<(C0, C1, C2, C3, C4, C5, C6, C7, C8, C9)> { ChartTupleContent() }
    public static func buildOptional<C>(_ content: C?) -> C? { content }
    public static func buildEither<T, F>(first content: T) -> ChartEither<T, F> { .first(content) }
    public static func buildEither<T, F>(second content: F) -> ChartEither<T, F> { .second(content) }
    public static func buildExpression(_ expression: Never) -> Never {}
    public static func buildBlock(_ n: Never) -> Never {}
    public static func buildArray<C>(_ components: [C]) -> [C] { components }
    public static func buildLimitedAvailability<C>(_ content: C) -> C { content }
}

public struct EmptyChartContent: ChartContent {
    public var body: some View { EmptyView() }
}
public struct ChartTupleContent<T>: ChartContent {
    public var body: some View { EmptyView() }
}
public enum ChartEither<T, F>: ChartContent {
    case first(T), second(F)
    public var body: some View { EmptyView() }
}

// MARK: - BarMark

public struct BarMark: View, ChartContent {
    public var body: some View { EmptyView() }

    // Standard x/y
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>, width: MarkDimension = .automatic, height: MarkDimension = .automatic, stacking: MarkStackingMethod = .standard) {}
    public init(x: PlottableValue<String>? = nil, y: PlottableValue<Double>? = nil) {}
    public init(x: PlottableValue<Double>? = nil, y: PlottableValue<String>? = nil) {}
    public init(x: PlottableValue<Int>? = nil, y: PlottableValue<Double>? = nil) {}
    public init(x: PlottableValue<Date>? = nil, y: PlottableValue<Double>? = nil) {}

    // Interval inits
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>, width: MarkDimension = .automatic) {}
    public init<X: Plottable, Y: Plottable>(xStart: PlottableValue<X>, xEnd: PlottableValue<X>, y: PlottableValue<Y>, height: MarkDimension = .automatic) {}
    public init<X: Plottable, Y: Plottable>(xStart: PlottableValue<X>, xEnd: PlottableValue<X>, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>) {}

    // Modifiers
    public func foregroundStyle(by value: PlottableValue<String>) -> BarMark { self }
    public func foregroundStyle(_ color: Color) -> BarMark { self }
    public func foregroundStyle<S: View>(_ style: S) -> BarMark { self }
    public func cornerRadius(_ radius: CGFloat, style: RoundedCornerStyle = .continuous) -> BarMark { self }
    public func annotation<Content: View>(position: AnnotationPosition = .automatic, alignment: Alignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) -> BarMark { self }
    public func annotation<Content: View>(position: AnnotationPosition = .automatic, alignment: Alignment = .center, spacing: CGFloat? = nil, overflowResolution: AnnotationOverflowResolution = .automatic, @ViewBuilder content: () -> Content) -> BarMark { self }
    public func position<P: Plottable>(by value: PlottableValue<P>, axis: Axis? = nil, span: MarkDimension = .automatic) -> BarMark { self }
    public func opacity(_ opacity: Double) -> BarMark { self }
    public func offset(_ offset: CGSize) -> BarMark { self }
    public func offset<X: Plottable>(x: PlottableValue<X>) -> BarMark { self }
    public func offset<Y: Plottable>(y: PlottableValue<Y>) -> BarMark { self }
    public func zIndex(_ index: Double) -> BarMark { self }
    public func clipShape<S: View>(_ shape: S) -> BarMark { self }
    public func mask<M: View>(@ViewBuilder content: () -> M) -> BarMark { self }
    public func accessibilityLabel(_ label: String) -> BarMark { self }
    public func accessibilityValue(_ value: String) -> BarMark { self }
    public func accessibilityIdentifier(_ identifier: String) -> BarMark { self }
    public func accessibilityHidden(_ hidden: Bool) -> BarMark { self }
}

// MARK: - LineMark

public struct LineMark: View, ChartContent {
    public var body: some View { EmptyView() }

    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>) {}
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>, series: PlottableValue<String>) {}
    public init(x: PlottableValue<String>? = nil, y: PlottableValue<Double>? = nil) {}
    public init(x: PlottableValue<Double>? = nil, y: PlottableValue<Double>? = nil) {}
    public init(x: PlottableValue<Date>? = nil, y: PlottableValue<Double>? = nil) {}

    public func foregroundStyle(_ color: Color) -> LineMark { self }
    public func foregroundStyle<S: View>(_ style: S) -> LineMark { self }
    public func foregroundStyle(by value: PlottableValue<String>) -> LineMark { self }
    public func interpolationMethod(_ method: InterpolationMethod) -> LineMark { self }
    public func lineStyle(_ style: StrokeStyle) -> LineMark { self }
    public func lineStyle(by value: PlottableValue<String>) -> LineMark { self }
    public func symbol<S: View>(_ shape: S) -> LineMark { self }
    public func symbol(by value: PlottableValue<String>) -> LineMark { self }
    public func symbolSize(_ size: CGFloat) -> LineMark { self }
    public func symbolSize(by value: PlottableValue<Double>) -> LineMark { self }
    public func opacity(_ opacity: Double) -> LineMark { self }
    public func offset(_ offset: CGSize) -> LineMark { self }
    public func zIndex(_ index: Double) -> LineMark { self }
    public func accessibilityLabel(_ label: String) -> LineMark { self }
    public func accessibilityValue(_ value: String) -> LineMark { self }
    public func accessibilityIdentifier(_ identifier: String) -> LineMark { self }
    public func accessibilityHidden(_ hidden: Bool) -> LineMark { self }
}

// MARK: - AreaMark

public struct AreaMark: View, ChartContent {
    public var body: some View { EmptyView() }

    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>, stacking: MarkStackingMethod = .standard) {}
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>) {}
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>, series: PlottableValue<String>) {}
    public init<X: Plottable, Y: Plottable>(xStart: PlottableValue<X>, xEnd: PlottableValue<X>, y: PlottableValue<Y>) {}
    public init<X: Plottable, Y: Plottable>(xStart: PlottableValue<X>, xEnd: PlottableValue<X>, y: PlottableValue<Y>, series: PlottableValue<String>) {}
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>, series: PlottableValue<String>, stacking: MarkStackingMethod = .standard) {}
    public init(x: PlottableValue<String>? = nil, y: PlottableValue<Double>? = nil) {}
    public init(x: PlottableValue<Date>? = nil, y: PlottableValue<Double>? = nil) {}

    public func foregroundStyle(_ color: Color) -> AreaMark { self }
    public func foregroundStyle<S: View>(_ style: S) -> AreaMark { self }
    public func foregroundStyle(by value: PlottableValue<String>) -> AreaMark { self }
    public func interpolationMethod(_ method: InterpolationMethod) -> AreaMark { self }
    public func opacity(_ opacity: Double) -> AreaMark { self }
    public func offset(_ offset: CGSize) -> AreaMark { self }
    public func zIndex(_ index: Double) -> AreaMark { self }
    public func accessibilityLabel(_ label: String) -> AreaMark { self }
    public func accessibilityValue(_ value: String) -> AreaMark { self }
    public func accessibilityIdentifier(_ identifier: String) -> AreaMark { self }
    public func accessibilityHidden(_ hidden: Bool) -> AreaMark { self }
}

// MARK: - PointMark

public struct PointMark: View, ChartContent {
    public var body: some View { EmptyView() }

    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>) {}
    public init(x: PlottableValue<String>? = nil, y: PlottableValue<Double>? = nil) {}
    public init(x: PlottableValue<Double>? = nil, y: PlottableValue<Double>? = nil) {}
    public init(x: PlottableValue<Date>? = nil, y: PlottableValue<Double>? = nil) {}

    public func foregroundStyle(_ color: Color) -> PointMark { self }
    public func foregroundStyle<S: View>(_ style: S) -> PointMark { self }
    public func foregroundStyle(by value: PlottableValue<String>) -> PointMark { self }
    public func symbol<S: View>(_ shape: S) -> PointMark { self }
    public func symbol(by value: PlottableValue<String>) -> PointMark { self }
    public func symbolSize(_ size: CGFloat) -> PointMark { self }
    public func symbolSize(by value: PlottableValue<Double>) -> PointMark { self }
    public func opacity(_ opacity: Double) -> PointMark { self }
    public func offset(_ offset: CGSize) -> PointMark { self }
    public func zIndex(_ index: Double) -> PointMark { self }
    public func accessibilityLabel(_ label: String) -> PointMark { self }
    public func accessibilityValue(_ value: String) -> PointMark { self }
    public func accessibilityIdentifier(_ identifier: String) -> PointMark { self }
    public func accessibilityHidden(_ hidden: Bool) -> PointMark { self }
}

// MARK: - RuleMark

public struct RuleMark: View, ChartContent {
    public var body: some View { EmptyView() }

    // Single line
    public init<Y: Plottable>(y: PlottableValue<Y>) {}
    public init<X: Plottable>(x: PlottableValue<X>) {}
    public init(y: PlottableValue<Double>? = nil) {}
    public init(x: PlottableValue<Double>? = nil) {}

    // Segment
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>) {}
    public init<X: Plottable, Y: Plottable>(xStart: PlottableValue<X>, xEnd: PlottableValue<X>, y: PlottableValue<Y>) {}

    public func foregroundStyle(_ color: Color) -> RuleMark { self }
    public func foregroundStyle<S: View>(_ style: S) -> RuleMark { self }
    public func foregroundStyle(by value: PlottableValue<String>) -> RuleMark { self }
    public func lineStyle(_ style: StrokeStyle) -> RuleMark { self }
    public func annotation<Content: View>(position: AnnotationPosition = .automatic, alignment: Alignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) -> RuleMark { self }
    public func opacity(_ opacity: Double) -> RuleMark { self }
    public func zIndex(_ index: Double) -> RuleMark { self }
    public func accessibilityLabel(_ label: String) -> RuleMark { self }
    public func accessibilityValue(_ value: String) -> RuleMark { self }
    public func accessibilityIdentifier(_ identifier: String) -> RuleMark { self }
    public func accessibilityHidden(_ hidden: Bool) -> RuleMark { self }
}

// MARK: - RectangleMark

public struct RectangleMark: View, ChartContent {
    public var body: some View { EmptyView() }

    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>, width: MarkDimension = .automatic, height: MarkDimension = .automatic) {}
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>, width: MarkDimension = .automatic) {}
    public init<X: Plottable, Y: Plottable>(xStart: PlottableValue<X>, xEnd: PlottableValue<X>, y: PlottableValue<Y>, height: MarkDimension = .automatic) {}
    public init<X: Plottable, Y: Plottable>(xStart: PlottableValue<X>, xEnd: PlottableValue<X>, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>) {}

    public func foregroundStyle(_ color: Color) -> RectangleMark { self }
    public func foregroundStyle<S: View>(_ style: S) -> RectangleMark { self }
    public func foregroundStyle(by value: PlottableValue<String>) -> RectangleMark { self }
    public func cornerRadius(_ radius: CGFloat, style: RoundedCornerStyle = .continuous) -> RectangleMark { self }
    public func opacity(_ opacity: Double) -> RectangleMark { self }
    public func offset(_ offset: CGSize) -> RectangleMark { self }
    public func zIndex(_ index: Double) -> RectangleMark { self }
    public func accessibilityLabel(_ label: String) -> RectangleMark { self }
    public func accessibilityValue(_ value: String) -> RectangleMark { self }
    public func accessibilityIdentifier(_ identifier: String) -> RectangleMark { self }
    public func accessibilityHidden(_ hidden: Bool) -> RectangleMark { self }
}

// MARK: - SectorMark

public struct SectorMark: View, ChartContent {
    public var body: some View { EmptyView() }

    public init<V: Plottable>(angle: PlottableValue<V>, innerRadius: MarkDimension = .automatic, outerRadius: MarkDimension = .automatic, angularInset: CGFloat = 0) {}

    public func foregroundStyle(_ color: Color) -> SectorMark { self }
    public func foregroundStyle<S: View>(_ style: S) -> SectorMark { self }
    public func foregroundStyle(by value: PlottableValue<String>) -> SectorMark { self }
    public func cornerRadius(_ radius: CGFloat, style: RoundedCornerStyle = .continuous) -> SectorMark { self }
    public func annotation<Content: View>(position: AnnotationPosition = .automatic, alignment: Alignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) -> SectorMark { self }
    public func opacity(_ opacity: Double) -> SectorMark { self }
    public func zIndex(_ index: Double) -> SectorMark { self }
    public func accessibilityLabel(_ label: String) -> SectorMark { self }
    public func accessibilityValue(_ value: String) -> SectorMark { self }
    public func accessibilityIdentifier(_ identifier: String) -> SectorMark { self }
    public func accessibilityHidden(_ hidden: Bool) -> SectorMark { self }
}

// MARK: - Enums

public enum AnnotationPosition {
    case automatic, top, bottom, leading, trailing
    case topLeading, topTrailing, bottomLeading, bottomTrailing
    case overlay
}

public struct AnnotationOverflowResolution: Sendable {
    public static let automatic = AnnotationOverflowResolution()
    public static let disabled = AnnotationOverflowResolution()
}

public enum InterpolationMethod {
    case linear, cardinal, catmullRom, monotone
    case stepStart, stepCenter, stepEnd
}

// MARK: - ChartSymbolShape

public protocol ChartSymbolShape: View {}

public struct BasicChartSymbolShape: ChartSymbolShape {
    public var body: some View { EmptyView() }

    public static let circle = BasicChartSymbolShape()
    public static let square = BasicChartSymbolShape()
    public static let triangle = BasicChartSymbolShape()
    public static let diamond = BasicChartSymbolShape()
    public static let pentagon = BasicChartSymbolShape()
    public static let cross = BasicChartSymbolShape()
    public static let plus = BasicChartSymbolShape()
    public static let asterisk = BasicChartSymbolShape()
}

// MARK: - Axis

public struct AxisMarks<Content>: View {
    public var body: some View { EmptyView() }

    public init(preset: AxisMarkPreset = .automatic, values: AxisMarkValues = .automatic, @ViewBuilder content: @escaping (AxisValue) -> Content) {}
    public init(preset: AxisMarkPreset = .automatic, position: AxisMarkPosition = .automatic, values: AxisMarkValues = .automatic, @ViewBuilder content: @escaping (AxisValue) -> Content) {}
    public init(preset: AxisMarkPreset = .automatic, position: AxisMarkPosition = .automatic, values: AxisMarkValues = .automatic, stroke: StrokeStyle? = nil, @ViewBuilder content: @escaping (AxisValue) -> Content) {}
}
extension AxisMarks where Content == Never {
    public init(preset: AxisMarkPreset = .automatic, values: AxisMarkValues = .automatic) {}
    public init(preset: AxisMarkPreset = .automatic, position: AxisMarkPosition = .automatic, values: AxisMarkValues = .automatic) {}
}

public enum AxisMarkPreset { case automatic, aligned, inset, extended }
public enum AxisMarkPosition { case automatic, leading, trailing, top, bottom }

public struct AxisMarkValues: Sendable {
    public static let automatic = AxisMarkValues()
    public static func automatic(desiredCount: Int? = nil, roundLowerBound: Bool = true, roundUpperBound: Bool = true) -> AxisMarkValues { AxisMarkValues() }
    public static func stride(by value: Int) -> AxisMarkValues { AxisMarkValues() }
    public static func stride(by value: Double) -> AxisMarkValues { AxisMarkValues() }
    public static func stride(by component: Calendar.Component, count: Int = 1) -> AxisMarkValues { AxisMarkValues() }
}

public struct AxisValue {
    public var index: Int { 0 }
    public func `as`<T>(_ type: T.Type) -> T? { nil }
}

public struct AxisValueLabel<Content: View>: View {
    public var body: some View { EmptyView() }
}
extension AxisValueLabel where Content == Text {
    public init() {}
    public init(_ label: String) {}
    public init(centered: Bool) {}
    public init(anchor: UnitPoint) {}
    public init<F: FormatStyle>(format: F) where F.FormatOutput == String {}
}
extension AxisValueLabel {
    public init(@ViewBuilder content: () -> Content) {}
}

public struct AxisGridLine: View {
    public init() {}
    public init(centered: Bool) {}
    public init(stroke: StrokeStyle) {}
    public func foregroundStyle(_ color: Color) -> AxisGridLine { self }
    public func foregroundStyle<S: View>(_ style: S) -> AxisGridLine { self }
    public var body: some View { EmptyView() }
}

public struct AxisTick: View {
    public init() {}
    public init(centered: Bool) {}
    public init(length: CGFloat) {}
    public init(stroke: StrokeStyle) {}
    public var body: some View { EmptyView() }
}

// MARK: - Chart Domain

public struct ChartDomain {
    public static func automatic(includesZero: Bool = false) -> ChartDomain { ChartDomain() }
}

// MARK: - ChartProxy

public struct ChartProxy {
    public func position<P: Plottable>(forX value: P) -> CGFloat? { nil }
    public func position<P: Plottable>(forY value: P) -> CGFloat? { nil }
    public func value<P: Plottable>(atX position: CGFloat, as type: P.Type) -> P? { nil }
    public func value<P: Plottable>(atY position: CGFloat, as type: P.Type) -> P? { nil }
    public var plotFrame: CGRect { .zero }
}

// MARK: - ChartPlotContent

public struct ChartPlotContent: View {
    public var body: some View { EmptyView() }
    public func frame(height: CGFloat) -> ChartPlotContent { self }
    public func frame(width: CGFloat) -> ChartPlotContent { self }
    public func frame(width: CGFloat?, height: CGFloat?) -> ChartPlotContent { self }
}

// MARK: - Chart Modifiers

extension Chart {
    // Axis content
    public func chartXAxis<A: View>(@ViewBuilder content: () -> A) -> Chart { self }
    public func chartYAxis<A: View>(@ViewBuilder content: () -> A) -> Chart { self }

    // Axis visibility
    public func chartXAxis(_ visibility: Visibility) -> Chart { self }
    public func chartYAxis(_ visibility: Visibility) -> Chart { self }

    // Axis labels
    public func chartXAxisLabel(_ label: String, position: Alignment = .center, alignment: Alignment = .center, spacing: CGFloat? = nil) -> Chart { self }
    public func chartXAxisLabel<L: View>(position: Alignment = .center, alignment: Alignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> L) -> Chart { self }
    public func chartYAxisLabel(_ label: String, position: Alignment = .center, alignment: Alignment = .center, spacing: CGFloat? = nil) -> Chart { self }
    public func chartYAxisLabel<L: View>(position: Alignment = .center, alignment: Alignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> L) -> Chart { self }

    // Scale
    public func chartXScale(domain: ChartDomain) -> Chart { self }
    public func chartXScale<T: Comparable>(domain: ClosedRange<T>) -> Chart { self }
    public func chartXScale<T: Plottable>(domain: [T]) -> Chart { self }
    public func chartYScale(domain: ChartDomain) -> Chart { self }
    public func chartYScale<T: Comparable>(domain: ClosedRange<T>) -> Chart { self }
    public func chartYScale<T: Plottable>(domain: [T]) -> Chart { self }

    // Foreground style scale
    public func chartForegroundStyleScale(_ mapping: [String: Color]) -> Chart { self }
    public func chartForegroundStyleScale<S>(_ scale: S) -> Chart { self }
    public func chartForegroundStyleScale<D: Plottable>(domain: [D], mapping: (D) -> Color) -> Chart { self }
    public func chartForegroundStyleScale<D: Plottable>(domain: [D], range: [Color]) -> Chart { self }

    // Symbol scale
    public func chartSymbolScale<S>(_ scale: S) -> Chart { self }
    public func chartSymbolScale<D: Plottable>(domain: [D]) -> Chart { self }
    public func chartSymbolScale<D: Plottable>(domain: [D], range: [BasicChartSymbolShape]) -> Chart { self }
    public func chartSymbolScale<D: Plottable>(domain: [D], mapping: (D) -> BasicChartSymbolShape) -> Chart { self }

    // Legend
    public func chartLegend(_ visibility: Visibility) -> Chart { self }
    public func chartLegend(position: AnnotationPosition = .automatic, alignment: Alignment = .center, spacing: CGFloat? = nil) -> Chart { self }
    public func chartLegend<L: View>(position: AnnotationPosition = .automatic, alignment: Alignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> L) -> Chart { self }

    // Plot style
    public func chartPlotStyle<S: View>(@ViewBuilder content: (ChartPlotContent) -> S) -> Chart { self }

    // Overlay / Background with ChartProxy
    public func chartOverlay<O: View>(alignment: Alignment = .center, @ViewBuilder content: (ChartProxy) -> O) -> Chart { self }
    public func chartBackground<B: View>(alignment: Alignment = .center, @ViewBuilder content: (ChartProxy) -> B) -> Chart { self }

    // Selection
    public func chartXSelection<T: Plottable>(value: Binding<T?>) -> Chart { self }
    public func chartXSelection<T: Plottable>(range: Binding<ClosedRange<T>?>) -> Chart { self }
    public func chartYSelection<T: Plottable>(value: Binding<T?>) -> Chart { self }
    public func chartYSelection<T: Plottable>(range: Binding<ClosedRange<T>?>) -> Chart { self }
    public func chartAngleSelection<T: Plottable>(value: Binding<T?>) -> Chart { self }

    // Scrolling
    public func chartScrollableAxes(_ axes: Axis.Set) -> Chart { self }
    public func chartXVisibleDomain<T: Plottable>(length: T) -> Chart { self }
    public func chartYVisibleDomain<T: Plottable>(length: T) -> Chart { self }
    public func chartScrollPosition<T: Plottable>(x: Binding<T?>) -> Chart { self }
    public func chartScrollPosition<T: Plottable>(y: Binding<T?>) -> Chart { self }
}
