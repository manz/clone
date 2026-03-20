import Foundation

// MARK: - Button styles

/// A type that applies custom appearance to all buttons within a view.
@MainActor
public protocol ButtonStyle {
    associatedtype Body: View
    func makeBody(configuration: Configuration) -> Body
    typealias Configuration = ButtonStyleConfiguration
}

/// The properties of a button.
public struct ButtonStyleConfiguration {
    public let label: ViewNode
    public let isPressed: Bool
}

/// A button style that doesn't apply a border.
public struct PlainButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { configuration.label }
}

/// A button style that doesn't apply a border.
public struct BorderlessButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { configuration.label }
}

/// A button style with a bordered appearance.
public struct BorderedButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { configuration.label }
}

/// A button style with a bordered prominent appearance.
public struct BorderedProminentButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { configuration.label }
}

// MARK: - ButtonStyle shorthand (`.buttonStyle(.bordered)`)

extension ButtonStyle where Self == PlainButtonStyle {
    public static var plain: PlainButtonStyle { PlainButtonStyle() }
}

extension ButtonStyle where Self == BorderlessButtonStyle {
    public static var borderless: BorderlessButtonStyle { BorderlessButtonStyle() }
}

extension ButtonStyle where Self == BorderedButtonStyle {
    public static var bordered: BorderedButtonStyle { BorderedButtonStyle() }
}

extension ButtonStyle where Self == BorderedProminentButtonStyle {
    public static var borderedProminent: BorderedProminentButtonStyle { BorderedProminentButtonStyle() }
}

// MARK: - List styles

/// A list style with no decoration.
public struct PlainListStyle { public init() {} }
/// An inset list style.
public struct InsetListStyle { public init() {} }
/// A grouped list style.
public struct GroupedListStyle { public init() {} }
/// A sidebar list style.
public struct SidebarListStyle { public init() {} }
/// An inset grouped list style.
public struct InsetGroupedListStyle { public init() {} }

// MARK: - TextField styles

/// A text field style with no decoration.
public struct PlainTextFieldStyle { public init() {} }
/// A text field style with a rounded border.
public struct RoundedBorderTextFieldStyle { public init() {} }

// MARK: - Picker styles

/// A protocol for picker styles.
public protocol PickerStyle {}

/// A segmented picker style.
public struct SegmentedPickerStyle: PickerStyle { public init() {} }
/// A menu picker style.
public struct MenuPickerStyle: PickerStyle { public init() {} }
/// The default picker style.
public struct DefaultPickerStyle: PickerStyle { public init() {} }
/// A wheel picker style.
public struct WheelPickerStyle: PickerStyle { public init() {} }
/// An inline picker style.
public struct InlinePickerStyle: PickerStyle { public init() {} }

extension PickerStyle where Self == SegmentedPickerStyle {
    public static var segmented: SegmentedPickerStyle { SegmentedPickerStyle() }
}
extension PickerStyle where Self == MenuPickerStyle {
    public static var menu: MenuPickerStyle { MenuPickerStyle() }
}
extension PickerStyle where Self == DefaultPickerStyle {
    public static var automatic: DefaultPickerStyle { DefaultPickerStyle() }
}
extension PickerStyle where Self == WheelPickerStyle {
    public static var wheel: WheelPickerStyle { WheelPickerStyle() }
}
extension PickerStyle where Self == InlinePickerStyle {
    public static var inline: InlinePickerStyle { InlinePickerStyle() }
}

// MARK: - Toggle styles

/// A toggle displayed as a switch.
public struct SwitchToggleStyle { public init() {} }
/// A toggle displayed as a checkbox.
public struct CheckboxToggleStyle { public init() {} }

// MARK: - ProgressView styles

/// A circular progress view style.
public struct CircularProgressViewStyle {
    public init() {}
    public init(tint: Color) {}
}
/// A linear progress view style.
public struct LinearProgressViewStyle {
    public init() {}
    public init(tint: Color) {}
}

// MARK: - Label styles

/// A type that applies custom appearance to all labels within a view.
@MainActor
public protocol LabelStyle {
    associatedtype Body: View
    func makeBody(configuration: LabelStyleConfiguration) -> Body
}

/// The properties of a label.
public struct LabelStyleConfiguration {}

/// A label style that only displays the title.
public struct TitleOnlyLabelStyle: LabelStyle {
    public init() {}
    public func makeBody(configuration: LabelStyleConfiguration) -> some View { EmptyView() }
}

/// A label style that only displays the icon.
public struct IconOnlyLabelStyle: LabelStyle {
    public init() {}
    public func makeBody(configuration: LabelStyleConfiguration) -> some View { EmptyView() }
}

/// A label style that displays both title and icon.
public struct TitleAndIconLabelStyle: LabelStyle {
    public init() {}
    public func makeBody(configuration: LabelStyleConfiguration) -> some View { EmptyView() }
}
