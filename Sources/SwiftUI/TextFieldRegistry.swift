import Foundation

/// Registry for text field focus and input handling.
/// Tracks all text fields in the current frame, manages focus, and routes key events.
public final class TextFieldRegistry: @unchecked Sendable {
    public static let shared = TextFieldRegistry()

    private struct Entry {
        var binding: Binding<String>
        let placeholder: String
        var frame: LayoutFrame?
    }

    private var entries: [UInt64: Entry] = [:]
    private var orderedIds: [UInt64] = []
    private var nextId: UInt64 = 1
    public private(set) var focusedId: UInt64?
    /// Persisted text across frame rebuilds, keyed by registration order
    private var persistedText: [Int: String] = [:]

    private init() {}

    // MARK: - Registration

    /// Register a text field and get a unique ID.
    /// Restores persisted text from previous frames if available.
    public func register(binding: Binding<String>, placeholder: String) -> UInt64 {
        let id = nextId
        nextId += 1
        let orderIndex = orderedIds.count
        entries[id] = Entry(binding: binding, placeholder: placeholder)
        orderedIds.append(id)
        // Restore persisted text from previous frame
        if let persisted = persistedText[orderIndex], !persisted.isEmpty {
            binding.wrappedValue = persisted
        }
        return id
    }

    /// Set the layout frame for a registered text field (called during layout).
    public func setFrame(id: UInt64, frame: LayoutFrame) {
        entries[id]?.frame = frame
    }

    // MARK: - Focus

    public func focus(id: UInt64) {
        guard entries[id] != nil else { return }
        focusedId = id
    }

    public func unfocus() {
        focusedId = nil
    }

    // MARK: - Input

    /// Handle a typed character — appends to the focused field's binding.
    public func handleKeyChar(_ char: String) {
        guard let id = focusedId, let entry = entries[id] else { return }
        entry.binding.wrappedValue += char
        persistText(for: id)
    }

    /// Handle backspace — removes the last character from the focused field.
    public func handleBackspace() {
        guard let id = focusedId, let entry = entries[id] else { return }
        var text = entry.binding.wrappedValue
        if !text.isEmpty {
            text.removeLast()
            entry.binding.wrappedValue = text
            persistText(for: id)
        }
    }

    private func persistText(for id: UInt64) {
        guard let entry = entries[id],
              let orderIndex = orderedIds.firstIndex(of: id) else { return }
        persistedText[Int(orderIndex)] = entry.binding.wrappedValue
    }

    /// Handle tab — move focus to the next text field.
    public func handleTab() {
        guard let currentId = focusedId,
              let currentIndex = orderedIds.firstIndex(of: currentId) else { return }
        let nextIndex = (currentIndex + 1) % orderedIds.count
        focusedId = orderedIds[nextIndex]
    }

    /// Handle return/enter — could submit or move to next field.
    public func handleReturn() {
        // For now, same as tab
        handleTab()
    }

    // MARK: - Hit Testing

    /// Handle a click — focus the text field at the given position, or unfocus all.
    public func handleClick(x: CGFloat, y: CGFloat) {
        for (id, entry) in entries {
            if let frame = entry.frame, frame.contains(x: x, y: y) {
                focusedId = id
                return
            }
        }
        focusedId = nil
    }

    // MARK: - Query

    /// Get the current text for a registered field.
    public func text(for id: UInt64) -> String? {
        entries[id]?.binding.wrappedValue
    }

    /// Get the placeholder for a registered field.
    public func placeholder(for id: UInt64) -> String? {
        entries[id]?.placeholder
    }

    /// Whether a field is focused.
    public func isFocused(_ id: UInt64) -> Bool {
        focusedId == id
    }

    // MARK: - Lifecycle

    /// Clear all entries (called each frame before rebuilding the view tree).
    /// Preserves the focused ID so focus persists across frames.
    public func clear() {
        entries.removeAll()
        orderedIds.removeAll()
        nextId = 1
        // NOTE: focusedId is NOT cleared — focus persists across rebuilds
    }

    /// Full reset including focus and persisted text (for tests).
    public func reset() {
        entries.removeAll()
        orderedIds.removeAll()
        persistedText.removeAll()
        nextId = 1
        focusedId = nil
    }
}
