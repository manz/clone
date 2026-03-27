import Foundation

/// Grid column specification for Layout.
public struct GridColumnSpec: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case fixed(CGFloat)
        case flexible(min: CGFloat, max: CGFloat)
        case adaptive(min: CGFloat, max: CGFloat)
    }
    public let kind: Kind
    public init(_ kind: Kind) { self.kind = kind }
}

/// Core view vocabulary — the entire UI is described as a tree of ViewNode values.
/// Fully value-typed, Equatable, trivially diffable.
///
/// **Internal use only.** App code should use the SwiftUI DSL functions
/// (`VStack`, `HStack`, `ZStack`, `Text`, `Rectangle`, etc.) and never
/// reference `ViewNode` directly.
/// Sendable wrapper for AnyHashable (used in .tagged).
public struct SendableHashable: Hashable, @unchecked Sendable {
    public let value: AnyHashable
    public init(_ value: AnyHashable) { self.value = value }
    public static func == (lhs: SendableHashable, rhs: SendableHashable) -> Bool { lhs.value == rhs.value }
    public func hash(into hasher: inout Hasher) { hasher.combine(value) }
}

public indirect enum ViewNode: Equatable, Sendable {
    case empty
    case text(String, fontSize: CGFloat, color: Color, weight: FontWeight = .regular, family: String? = nil)
    case rect(width: CGFloat?, height: CGFloat?, fill: Color)
    case roundedRect(width: CGFloat?, height: CGFloat?, radius: CGFloat, fill: Color)
    case blur(radius: CGFloat)
    case spacer(minLength: CGFloat)
    case vstack(alignment: HAlignment, spacing: CGFloat, children: [ViewNode])
    case hstack(alignment: VAlignment, spacing: CGFloat, children: [ViewNode])
    case zstack(alignment: Alignment = .center, children: [ViewNode])
    case padding(EdgeInsets, child: ViewNode)
    case frame(width: CGFloat?, height: CGFloat?, child: ViewNode)
    case opacity(CGFloat, child: ViewNode)
    case shadow(radius: CGFloat, blur: CGFloat, color: Color, offsetX: CGFloat, offsetY: CGFloat, child: ViewNode)
    case onTap(id: UInt64, child: ViewNode)
    case onHover(id: UInt64, child: ViewNode)
    case geometryReader(id: UInt64)

    // Step 4 additions
    case scrollView(axis: Axis, children: [ViewNode], key: String)
    case list(children: [ViewNode])
    case image(name: String, width: CGFloat?, height: CGFloat?, tint: Color? = nil)
    /// Raster image (JPEG, PNG) with decoded RGBA pixel data.
    case rasterImage(textureId: UInt64, imageWidth: UInt32, imageHeight: UInt32, rgbaData: [UInt8])
    case toggle(isOn: Bool, label: ViewNode)
    case slider(value: CGFloat, range: ClosedRange<CGFloat>, label: ViewNode)
    case picker(selection: String, label: ViewNode, children: [ViewNode])
    case textField(placeholder: String, text: String, registryId: UInt64 = 0)
    case grid(columns: [GridColumnSpec], spacing: CGFloat, children: [ViewNode])
    case navigationStack(children: [ViewNode])
    case menu(label: String, children: [ViewNode])
    case contextMenu(child: ViewNode, menuItems: [ViewNode])
    case clipped(radius: CGFloat, child: ViewNode)
    case tagged(tag: SendableHashable, child: ViewNode)
    case toolbarItem(placement: ToolbarItemPlacement, child: ViewNode)
    case lineLimit(limit: Int?, child: ViewNode)

    /// Whether this node is an opaque visual element that should absorb tap events
    /// (prevent them from leaking through to views behind it).
    var isOpaqueHitTarget: Bool {
        switch self {
        case .rect, .roundedRect, .image, .rasterImage, .toggle, .slider, .picker, .textField:
            return true
        default:
            return false
        }
    }
}

/// Axis for ScrollView direction.
public enum Axis: Equatable, Sendable {
    case horizontal
    case vertical
}
