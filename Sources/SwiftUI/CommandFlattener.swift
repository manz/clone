import Foundation

/// Flattens a laid-out ViewNode tree into absolute-positioned render commands.
/// These map 1:1 to the Rust RenderCommand enum.
public struct FlatRenderCommand: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case rect(color: Color)
        case roundedRect(radius: Float, color: Color)
        case text(content: String, fontSize: Float, color: Color, weight: FontWeight = .regular)
        case shadow(radius: Float, blur: Float, color: Color, offsetX: Float, offsetY: Float)
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

        case .shadow(let radius, let blur, let color, let offsetX, let offsetY, _):
            // Emit shadow command for the child's frame, then recurse into children
            commands.append(FlatRenderCommand(
                x: frame.x, y: frame.y,
                width: frame.width, height: frame.height,
                kind: .shadow(radius: radius, blur: blur,
                             color: color.withAlpha(color.a * opacity),
                             offsetX: offsetX, offsetY: offsetY)
            ))
            for child in layoutNode.children {
                flattenNode(child, into: &commands, opacity: opacity)
            }
            return

        case .opacity(let value, _):
            for child in layoutNode.children {
                flattenNode(child, into: &commands, opacity: opacity * value)
            }
            return

        case .image(_, _, _):
            // Placeholder rect until image loading is implemented
            commands.append(FlatRenderCommand(
                x: frame.x, y: frame.y,
                width: frame.width, height: frame.height,
                kind: .rect(color: Color.muted.withAlpha(0.3 * opacity))
            ))

        case .toggle(let isOn, _):
            // Track background
            let trackColor: Color = isOn ? .systemGreen : .muted
            let trackW: Float = 44
            let trackH: Float = 24
            let trackX = frame.x + frame.width - trackW - 8
            let trackY = frame.y + (frame.height - trackH) / 2
            commands.append(FlatRenderCommand(
                x: trackX, y: trackY, width: trackW, height: trackH,
                kind: .roundedRect(radius: trackH / 2, color: trackColor.withAlpha(opacity))
            ))
            // Knob
            let knobSize: Float = 20
            let knobX = isOn ? trackX + trackW - knobSize - 2 : trackX + 2
            let knobY = trackY + 2
            commands.append(FlatRenderCommand(
                x: knobX, y: knobY, width: knobSize, height: knobSize,
                kind: .roundedRect(radius: knobSize / 2, color: Color.white.withAlpha(opacity))
            ))

        case .slider(let value, let range, _):
            let trackH: Float = 4
            let trackY = frame.y + (frame.height - trackH) / 2
            commands.append(FlatRenderCommand(
                x: frame.x, y: trackY, width: frame.width, height: trackH,
                kind: .roundedRect(radius: 2, color: Color.muted.withAlpha(opacity))
            ))
            let t = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let knobX = frame.x + t * (frame.width - 16)
            commands.append(FlatRenderCommand(
                x: knobX, y: frame.y + (frame.height - 16) / 2, width: 16, height: 16,
                kind: .roundedRect(radius: 8, color: Color.white.withAlpha(opacity))
            ))

        case .textField(let placeholder, let text):
            // Background box
            commands.append(FlatRenderCommand(
                x: frame.x, y: frame.y, width: frame.width, height: frame.height,
                kind: .roundedRect(radius: 6, color: Color.surface.withAlpha(opacity))
            ))
            // Text content or placeholder
            let displayText = text.isEmpty ? placeholder : text
            let textColor = text.isEmpty ? Color.muted : Color.text
            commands.append(FlatRenderCommand(
                x: frame.x + 8, y: frame.y + 7, width: frame.width - 16, height: 14,
                kind: .text(content: displayText, fontSize: 14, color: textColor.withAlpha(opacity))
            ))

        default:
            break
        }

        // Recurse into children (unless already handled above)
        if case .opacity = layoutNode.node { return }
        if case .shadow = layoutNode.node { return }
        for child in layoutNode.children {
            flattenNode(child, into: &commands, opacity: opacity)
        }
    }
}

// Helper
extension Color {
    func withAlpha(_ alpha: Float) -> Color {
        Color(r: r, g: g, b: b, a: alpha)
    }
}
