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

/// A button style with a glass appearance.
public struct GlassButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { configuration.label }
}

extension ButtonStyle where Self == GlassButtonStyle {
    public static var glass: GlassButtonStyle { GlassButtonStyle() }
}

// MARK: - List styles

/// A type that applies custom appearance to lists.
public protocol ListStyle {}

/// A list style with no decoration.
public struct PlainListStyle: ListStyle { public init() {} }
/// An inset list style.
public struct InsetListStyle: ListStyle {
    public init() {}
    public init(alternatesRowBackgrounds: Bool) {}
}
/// A grouped list style.
public struct GroupedListStyle: ListStyle { public init() {} }
/// A sidebar list style.
public struct SidebarListStyle: ListStyle { public init() {} }
/// An inset grouped list style.
public struct InsetGroupedListStyle: ListStyle { public init() {} }

extension ListStyle where Self == PlainListStyle {
    public static var plain: PlainListStyle { PlainListStyle() }
}
extension ListStyle where Self == InsetListStyle {
    public static var inset: InsetListStyle { InsetListStyle() }
    public static func inset(alternatesRowBackgrounds: Bool) -> InsetListStyle { InsetListStyle(alternatesRowBackgrounds: alternatesRowBackgrounds) }
}
extension ListStyle where Self == GroupedListStyle {
    public static var grouped: GroupedListStyle { GroupedListStyle() }
}
extension ListStyle where Self == SidebarListStyle {
    public static var sidebar: SidebarListStyle { SidebarListStyle() }
}
extension ListStyle where Self == InsetGroupedListStyle {
    public static var insetGrouped: InsetGroupedListStyle { InsetGroupedListStyle() }
}
/// A columns list style.
public struct ColumnsListStyle: ListStyle { public init() {} }

extension ListStyle where Self == ColumnsListStyle {
    public static var columns: ColumnsListStyle { ColumnsListStyle() }
}

// MARK: - TextField styles

/// A type that applies custom appearance to text fields.
public protocol TextFieldStyle {}

/// A text field style with no decoration.
public struct PlainTextFieldStyle: TextFieldStyle { public init() {} }
/// A text field style with a rounded border.
public struct RoundedBorderTextFieldStyle: TextFieldStyle { public init() {} }

extension TextFieldStyle where Self == PlainTextFieldStyle {
    public static var plain: PlainTextFieldStyle { PlainTextFieldStyle() }
}
extension TextFieldStyle where Self == RoundedBorderTextFieldStyle {
    public static var roundedBorder: RoundedBorderTextFieldStyle { RoundedBorderTextFieldStyle() }
}

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

/// A type that applies custom appearance to toggles.
public protocol ToggleStyle {}

/// A toggle displayed as a switch.
public struct SwitchToggleStyle: ToggleStyle { public init() {} }
/// A toggle displayed as a checkbox.
public struct CheckboxToggleStyle: ToggleStyle { public init() {} }

extension ToggleStyle where Self == SwitchToggleStyle {
    public static var `switch`: SwitchToggleStyle { SwitchToggleStyle() }
}
extension ToggleStyle where Self == CheckboxToggleStyle {
    public static var checkbox: CheckboxToggleStyle { CheckboxToggleStyle() }
}

// MARK: - ProgressView styles

/// A type that applies custom appearance to progress views.
public protocol ProgressViewStyle {}

/// A circular progress view style.
public struct CircularProgressViewStyle: ProgressViewStyle {
    public init() {}
    public init(tint: Color) {}
}
/// A linear progress view style.
public struct LinearProgressViewStyle: ProgressViewStyle {
    public init() {}
    public init(tint: Color) {}
}

extension ProgressViewStyle where Self == CircularProgressViewStyle {
    public static var circular: CircularProgressViewStyle { CircularProgressViewStyle() }
}
extension ProgressViewStyle where Self == LinearProgressViewStyle {
    public static var linear: LinearProgressViewStyle { LinearProgressViewStyle() }
}

// MARK: - Menu styles

/// A type that applies custom appearance to menus.
public protocol MenuStyle {}
public struct DefaultMenuStyle: MenuStyle { public init() {} }
public struct BorderedButtonMenuStyle: MenuStyle { public init() {} }

extension MenuStyle where Self == DefaultMenuStyle {
    public static var automatic: DefaultMenuStyle { DefaultMenuStyle() }
}
extension MenuStyle where Self == BorderedButtonMenuStyle {
    public static var borderedButton: BorderedButtonMenuStyle { BorderedButtonMenuStyle() }
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

/// Default label style.
public struct DefaultLabelStyle: LabelStyle {
    public init() {}
    public func makeBody(configuration: LabelStyleConfiguration) -> some View { EmptyView() }
}

extension LabelStyle where Self == TitleOnlyLabelStyle {
    public static var titleOnly: TitleOnlyLabelStyle { TitleOnlyLabelStyle() }
}
extension LabelStyle where Self == IconOnlyLabelStyle {
    public static var iconOnly: IconOnlyLabelStyle { IconOnlyLabelStyle() }
}
extension LabelStyle where Self == TitleAndIconLabelStyle {
    public static var titleAndIcon: TitleAndIconLabelStyle { TitleAndIconLabelStyle() }
}
extension LabelStyle where Self == DefaultLabelStyle {
    public static var automatic: DefaultLabelStyle { DefaultLabelStyle() }
}

// MARK: - Form styles

public protocol FormStyle {}

public struct DefaultFormStyle: FormStyle { public init() {} }
public struct GroupedFormStyle: FormStyle { public init() {} }
public struct ColumnsFormStyle: FormStyle { public init() {} }

extension FormStyle where Self == DefaultFormStyle {
    public static var automatic: DefaultFormStyle { DefaultFormStyle() }
}
extension FormStyle where Self == GroupedFormStyle {
    public static var grouped: GroupedFormStyle { GroupedFormStyle() }
}
extension FormStyle where Self == ColumnsFormStyle {
    public static var columns: ColumnsFormStyle { ColumnsFormStyle() }
}
