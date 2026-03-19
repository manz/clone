/// Core view vocabulary — the entire UI is described as a tree of ViewNode values.
/// Fully value-typed, Equatable, trivially diffable.
public indirect enum ViewNode: Equatable, Sendable {
    case empty
    case text(String, fontSize: Float, color: DesktopColor, weight: FontWeight = .regular)
    case rect(width: Float?, height: Float?, fill: DesktopColor)
    case roundedRect(width: Float?, height: Float?, radius: Float, fill: DesktopColor)
    case blur(radius: Float)
    case spacer(minLength: Float)
    case vstack(alignment: HAlignment, spacing: Float, children: [ViewNode])
    case hstack(alignment: VAlignment, spacing: Float, children: [ViewNode])
    case zstack(children: [ViewNode])
    case padding(EdgeInsets, child: ViewNode)
    case frame(width: Float?, height: Float?, child: ViewNode)
    case opacity(Float, child: ViewNode)
    case onTap(id: UInt64, child: ViewNode)
    case geometryReader(id: UInt64)
}
