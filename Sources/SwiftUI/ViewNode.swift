/// Core view vocabulary — the entire UI is described as a tree of ViewNode values.
/// Fully value-typed, Equatable, trivially diffable.
///
/// **Internal use only.** App code should use the SwiftUI DSL functions
/// (`VStack`, `HStack`, `ZStack`, `Text`, `Rectangle`, etc.) and never
/// reference `ViewNode` directly.
public indirect enum ViewNode: Equatable, Sendable {
    case empty
    case text(String, fontSize: Float, color: Color, weight: FontWeight = .regular)
    case rect(width: Float?, height: Float?, fill: Color)
    case roundedRect(width: Float?, height: Float?, radius: Float, fill: Color)
    case blur(radius: Float)
    case spacer(minLength: Float)
    case vstack(alignment: HAlignment, spacing: Float, children: [ViewNode])
    case hstack(alignment: VAlignment, spacing: Float, children: [ViewNode])
    case zstack(children: [ViewNode])
    case padding(EdgeInsets, child: ViewNode)
    case frame(width: Float?, height: Float?, child: ViewNode)
    case opacity(Float, child: ViewNode)
    case shadow(radius: Float, blur: Float, color: Color, offsetX: Float, offsetY: Float, child: ViewNode)
    case onTap(id: UInt64, child: ViewNode)
    case geometryReader(id: UInt64)

    // Step 4 additions
    case scrollView(axis: Axis, children: [ViewNode])
    case list(children: [ViewNode])
    case image(name: String, width: Float?, height: Float?)
    case toggle(isOn: Bool, label: ViewNode)
    case slider(value: Float, range: ClosedRange<Float>, label: ViewNode)
    case picker(selection: String, label: ViewNode, children: [ViewNode])
    case textField(placeholder: String, text: String)
    case navigationStack(children: [ViewNode])
    case menu(label: String, children: [ViewNode])
    case contextMenu(child: ViewNode, menuItems: [ViewNode])
    case clipped(radius: Float, child: ViewNode)
}

/// Axis for ScrollView direction.
public enum Axis: Equatable, Sendable {
    case horizontal
    case vertical
}
