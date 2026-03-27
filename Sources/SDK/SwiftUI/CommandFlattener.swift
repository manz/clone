import Foundation

/// Phosphor icon style — matches the SVG subdirectory names.
public enum PhosphorIconStyle: String, Equatable, Sendable {
    case regular, fill, duotone, thin, light, bold
}

/// Flattens a laid-out ViewNode tree into absolute-positioned render commands.
/// These map 1:1 to the Rust RenderCommand enum.
public struct FlatRenderCommand: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case rect(color: Color)
        case roundedRect(radius: CGFloat, color: Color)
        case text(content: String, fontSize: CGFloat, color: Color, weight: FontWeight = .regular, maxWidth: CGFloat? = nil, family: String? = nil)
        /// Phosphor SVG icon — name is the Phosphor icon name (e.g. "folder", "avocado").
        case icon(name: String, style: PhosphorIconStyle, color: Color)
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
        // Filter invalid and zero-size commands (but keep popClip which has zero size)
        return commands.filter { cmd in
            if case .popClip = cmd.kind { return true }
            return cmd.x.isFinite && cmd.y.isFinite && cmd.width.isFinite && cmd.height.isFinite
                && cmd.width > 0 && cmd.height > 0
        }
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

        case .text(let content, let fontSize, let color, let weight, let family):
            // Only send maxWidth when text actually needs wrapping (natural width > frame)
            let natural = TextMeasurer.measure(content, fontSize: fontSize, weight: weight)
            let needsWrap = natural.width > frame.width && frame.width > 0 && frame.width < 10000
            commands.append(FlatRenderCommand(
                x: frame.x, y: frame.y,
                width: frame.width, height: frame.height,
                kind: .text(content: content, fontSize: fontSize, color: color.withAlpha(color.a * opacity), weight: weight,
                           maxWidth: needsWrap ? frame.width : nil, family: family)
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

        case .image(let name, _, _, let tint):
            // Resolve SF Symbols name to Phosphor icon name + style
            let resolved = PhosphorIcons.resolve(name: name)
            let iconColor = tint ?? Color.primary
            let iconSize = min(frame.width, frame.height)
            let iconX = frame.x + (frame.width - iconSize) / 2
            let iconY = frame.y + (frame.height - iconSize) / 2
            commands.append(FlatRenderCommand(
                x: iconX, y: iconY,
                width: iconSize, height: iconSize,
                kind: .icon(name: resolved.name, style: resolved.style,
                           color: iconColor.withAlpha(opacity))
            ))

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

        case .textField(let placeholder, let text, let registryId):
            let isFocused = TextFieldRegistry.shared.isFocused(registryId)
            // Background box — highlight when focused
            let bgColor = isFocused ? Color(red: 0.9, green: 0.95, blue: 1.0) : WindowChrome.surface
            commands.append(FlatRenderCommand(
                x: frame.x, y: frame.y, width: frame.width, height: frame.height,
                kind: .roundedRect(radius: 6, color: bgColor.withAlpha(opacity))
            ))
            // Read live text from registry (binding), fall back to ViewNode text
            let liveText = TextFieldRegistry.shared.text(for: registryId) ?? text
            let displayText = liveText.isEmpty ? placeholder : liveText
            let textColor = liveText.isEmpty ? Color.gray : Color.primary
            commands.append(FlatRenderCommand(
                x: frame.x + 8, y: frame.y + 7, width: frame.width - 16, height: 14,
                kind: .text(content: displayText, fontSize: 14, color: textColor.withAlpha(opacity))
            ))
            // Cursor when focused
            if isFocused {
                let cursorX = frame.x + 8 + CGFloat(liveText.count) * 14 * 0.6
                commands.append(FlatRenderCommand(
                    x: cursorX, y: frame.y + 5, width: 1, height: frame.height - 10,
                    kind: .rect(color: Color.primary.withAlpha(opacity))
                ))
            }

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
