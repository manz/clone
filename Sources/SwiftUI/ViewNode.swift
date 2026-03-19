import Foundation

/// Core view vocabulary — the entire UI is described as a tree of ViewNode values.
/// Fully value-typed, Equatable, trivially diffable.
///
/// **Internal use only.** App code should use the SwiftUI DSL functions
/// (`VStack`, `HStack`, `ZStack`, `Text`, `Rectangle`, etc.) and never
/// reference `ViewNode` directly.
public indirect enum ViewNode: Equatable, Sendable {
    case empty
    case text(String, fontSize: CGFloat, color: Color, weight: FontWeight = .regular)
    case rect(width: CGFloat?, height: CGFloat?, fill: Color)
    case roundedRect(width: CGFloat?, height: CGFloat?, radius: CGFloat, fill: Color)
    case blur(radius: CGFloat)
    case spacer(minLength: CGFloat)
    case vstack(alignment: HAlignment, spacing: CGFloat, children: [ViewNode])
    case hstack(alignment: VAlignment, spacing: CGFloat, children: [ViewNode])
    case zstack(children: [ViewNode])
    case padding(EdgeInsets, child: ViewNode)
    case frame(width: CGFloat?, height: CGFloat?, child: ViewNode)
    case opacity(CGFloat, child: ViewNode)
    case shadow(radius: CGFloat, blur: CGFloat, color: Color, offsetX: CGFloat, offsetY: CGFloat, child: ViewNode)
    case onTap(id: UInt64, child: ViewNode)
    case geometryReader(id: UInt64)

    // Step 4 additions
    case scrollView(axis: Axis, children: [ViewNode])
    case list(children: [ViewNode])
    case image(name: String, width: CGFloat?, height: CGFloat?)
    case toggle(isOn: Bool, label: ViewNode)
    case slider(value: CGFloat, range: ClosedRange<CGFloat>, label: ViewNode)
    case picker(selection: String, label: ViewNode, children: [ViewNode])
    case textField(placeholder: String, text: String)
    case navigationStack(children: [ViewNode])
    case menu(label: String, children: [ViewNode])
    case contextMenu(child: ViewNode, menuItems: [ViewNode])
    case clipped(radius: CGFloat, child: ViewNode)
}

/// Axis for ScrollView direction.
public enum Axis: Equatable, Sendable {
    case horizontal
    case vertical
}
