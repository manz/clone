import Foundation

/// Flattens a laid-out ViewNode tree into absolute-positioned render commands.
/// These map 1:1 to the Rust RenderCommand enum.
public struct FlatRenderCommand: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case rect(color: Color)
        case roundedRect(radius: CGFloat, color: Color)
        case text(content: String, fontSize: CGFloat, color: Color, weight: FontWeight = .regular, isIcon: Bool = false)
        case shadow(radius: CGFloat, blur: CGFloat, color: Color, offsetX: CGFloat, offsetY: CGFloat)
        case pushClip(radius: CGFloat)
        case popClip
    }

    public let x: CGFloat
    public let y: CGFloat
    public let width: CGFloat
    public let height: CGFloat
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
        opacity: CGFloat
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

        case .menu(let label, _):
            // Render just the label text (collapsed state)
            commands.append(FlatRenderCommand(
                x: frame.x, y: frame.y,
                width: frame.width, height: frame.height,
                kind: .text(content: label, fontSize: 14, color: Color.primary.withAlpha(opacity))
            ))

        case .contextMenu(_, _):
            // Flatten the child; menu items are rendered on demand by the app
            for child in layoutNode.children {
                flattenNode(child, into: &commands, opacity: opacity)
            }
            return

        case .clipped(let radius, _):
            // Emit clip boundary so the renderer flushes batches before and after
            commands.append(FlatRenderCommand(
                x: frame.x, y: frame.y, width: frame.width, height: frame.height,
                kind: .pushClip(radius: radius)
            ))
            for child in layoutNode.children {
                flattenNode(child, into: &commands, opacity: opacity)
            }
            commands.append(FlatRenderCommand(
                x: 0, y: 0, width: 0, height: 0,
                kind: .popClip
            ))
            return

        case .image(let name, _, _):
            // Try Phosphor icon font, fall back to placeholder rect
            if let char = PhosphorIcons.character(forName: name) {
                let iconSize = min(frame.width, frame.height)
                let iconX = frame.x + (frame.width - iconSize) / 2
                let iconY = frame.y + (frame.height - iconSize) / 2
                commands.append(FlatRenderCommand(
                    x: iconX, y: iconY,
                    width: iconSize, height: iconSize,
                    kind: .text(content: String(char), fontSize: iconSize,
                               color: Color.primary.withAlpha(opacity), isIcon: true)
                ))
            } else {
                commands.append(FlatRenderCommand(
                    x: frame.x, y: frame.y,
                    width: frame.width, height: frame.height,
                    kind: .rect(color: Color.gray.withAlpha(0.3 * opacity))
                ))
            }

        case .toggle(let isOn, _):
            // Track background
            let trackColor: Color = isOn ? .green : .gray
            let trackW: CGFloat = 44
            let trackH: CGFloat = 24
            let trackX = frame.x + frame.width - trackW - 8
            let trackY = frame.y + (frame.height - trackH) / 2
            commands.append(FlatRenderCommand(
                x: trackX, y: trackY, width: trackW, height: trackH,
                kind: .roundedRect(radius: trackH / 2, color: trackColor.withAlpha(opacity))
            ))
            // Knob
            let knobSize: CGFloat = 20
            let knobX = isOn ? trackX + trackW - knobSize - 2 : trackX + 2
            let knobY = trackY + 2
            commands.append(FlatRenderCommand(
                x: knobX, y: knobY, width: knobSize, height: knobSize,
                kind: .roundedRect(radius: knobSize / 2, color: Color.white.withAlpha(opacity))
            ))

        case .slider(let value, let range, _):
            let trackH: CGFloat = 4
            let trackY = frame.y + (frame.height - trackH) / 2
            commands.append(FlatRenderCommand(
                x: frame.x, y: trackY, width: frame.width, height: trackH,
                kind: .roundedRect(radius: 2, color: Color.gray.withAlpha(opacity))
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
                kind: .roundedRect(radius: 6, color: WindowChrome.surface.withAlpha(opacity))
            ))
            // Text content or placeholder
            let displayText = text.isEmpty ? placeholder : text
            let textColor = text.isEmpty ? Color.gray : Color.primary
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
    func withAlpha(_ alpha: CGFloat) -> Color {
        Color(r: r, g: g, b: b, a: alpha)
    }
}
