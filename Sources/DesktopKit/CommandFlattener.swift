import Foundation

/// Flattens a laid-out ViewNode tree into absolute-positioned render commands.
/// These map 1:1 to the Rust RenderCommand enum.
public struct FlatRenderCommand: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case rect(color: DesktopColor)
        case roundedRect(radius: Float, color: DesktopColor)
        case text(content: String, fontSize: Float, color: DesktopColor, weight: FontWeight = .regular)
    }

    public let x: Float
    public let y: Float
    public let width: Float
    public let height: Float
    public let kind: Kind
}

public enum CommandFlattener {

    /// Walk a LayoutNode tree and emit flat render commands.
    public static func flatten(_ layoutNode: LayoutNode) -> [FlatRenderCommand] {
        var commands: [FlatRenderCommand] = []
        flattenNode(layoutNode, into: &commands, opacity: 1.0)
        return commands
    }

    private static func flattenNode(
        _ layoutNode: LayoutNode,
        into commands: inout [FlatRenderCommand],
        opacity: Float
    ) {
        let frame = layoutNode.frame

        switch layoutNode.node {
        case .rect(_, _, let fill):
            commands.append(FlatRenderCommand(
                x: frame.x, y: frame.y,
                width: frame.width, height: frame.height,
                kind: .rect(color: fill.withAlpha(fill.a * opacity))
            ))

        case .roundedRect(_, _, let radius, let fill):
            commands.append(FlatRenderCommand(
                x: frame.x, y: frame.y,
                width: frame.width, height: frame.height,
                kind: .roundedRect(radius: radius, color: fill.withAlpha(fill.a * opacity))
            ))

        case .text(let content, let fontSize, let color, let weight):
            commands.append(FlatRenderCommand(
                x: frame.x, y: frame.y,
                width: frame.width, height: frame.height,
                kind: .text(content: content, fontSize: fontSize, color: color.withAlpha(color.a * opacity), weight: weight)
            ))

        case .opacity(let value, _):
            for child in layoutNode.children {
                flattenNode(child, into: &commands, opacity: opacity * value)
            }
            return

        default:
            break
        }

        // Recurse into children (unless already handled above)
        if case .opacity = layoutNode.node { return }
        for child in layoutNode.children {
            flattenNode(child, into: &commands, opacity: opacity)
        }
    }
}

// Helper
extension DesktopColor {
    func withAlpha(_ alpha: Float) -> DesktopColor {
        DesktopColor(r: r, g: g, b: b, a: alpha)
    }
}
