import Foundation

/// Dock layout constants and animation target computation.
/// Used by the compositor to calculate minimize/restore animation targets.
/// Must mirror the dock app's zone layout:
///   [pinned apps] | [unpinned running] | [minimized windows] | [trash]
@MainActor
public struct Dock {
    public static let baseIconSize: CGFloat = 48
    public static let padding: CGFloat = 8
    public static let dockHeight: CGFloat = 64
    public static let separatorWidth: CGFloat = 2
    public static let separatorPadding: CGFloat = 6

    /// Pinned apps — must match the dock app's pinnedItems list.
    public static let pinnedAppIds: [String] = [
        "com.clone.finder",
        "com.clone.settings",
        "com.clone.textedit",
        "com.clone.preview",
        "com.clone.password",
    ]

    /// Compute the screen-space rect for a minimize target slot in the minimized zone.
    /// `slotIndex` is the position within the minimized zone (0 = first minimized window).
    public static func minimizeTargetRect(
        slotIndex: Int,
        pinnedCount: Int,
        unpinnedRunningCount: Int,
        minimizedCount: Int,
        screenWidth: CGFloat,
        screenHeight: CGFloat
    ) -> AnimRect {
        // Compute total dock width to find the center offset
        let hasSep1 = unpinnedRunningCount > 0 || minimizedCount > 0
        let hasSep2 = unpinnedRunningCount > 0 && minimizedCount > 0
        let hasTrashSep = unpinnedRunningCount > 0 || minimizedCount > 0

        let iconCount = pinnedCount + unpinnedRunningCount
        let iconWidth = CGFloat(iconCount) * baseIconSize + CGFloat(max(iconCount - 1, 0)) * padding
        let minimizedWidth = CGFloat(minimizedCount) * (baseIconSize + padding)
        let trashWidth = baseIconSize + padding
        let sepSpace = (hasSep1 ? separatorWidth + separatorPadding * 2 : 0)
            + (hasSep2 ? separatorWidth + separatorPadding * 2 : 0)
            + (hasTrashSep ? separatorWidth + separatorPadding * 2 : 0)
        let totalWidth = iconWidth + minimizedWidth + trashWidth + sepSpace + padding * 2

        let startX = (screenWidth - totalWidth) / 2 + padding

        // Offset past pinned icons
        var x = startX + CGFloat(pinnedCount) * (baseIconSize + padding)
        // Separator after pinned
        if hasSep1 { x += separatorWidth + separatorPadding * 2 }
        // Offset past unpinned running icons
        x += CGFloat(unpinnedRunningCount) * (baseIconSize + padding)
        // Separator after unpinned
        if hasSep2 { x += separatorWidth + separatorPadding * 2 }
        // Offset to the target slot
        x += CGFloat(slotIndex) * (baseIconSize + padding)

        let dockY = screenHeight - dockHeight - padding * 2
        let y = dockY + padding + (dockHeight - baseIconSize) / 2

        return AnimRect(x: x, y: y, w: baseIconSize, h: baseIconSize)
    }
}
