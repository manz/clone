import Testing
import Foundation
@testable import SwiftUI

// MARK: - TextFieldRegistry tests

@Test @MainActor func textFieldRegistryRegisterAndFocus() {
    let registry = TextFieldRegistry.shared
    registry.reset()

    var text = ""
    let binding = Binding(get: { text }, set: { text = $0 })
    let id = registry.register(binding: binding, placeholder: "Name")

    #expect(registry.focusedId == nil)
    registry.focus(id: id)
    #expect(registry.focusedId == id)
}

@Test @MainActor func textFieldRegistryTypeCharacter() {
    let registry = TextFieldRegistry.shared
    registry.reset()

    var text = ""
    let binding = Binding(get: { text }, set: { text = $0 })
    let id = registry.register(binding: binding, placeholder: "Name")
    registry.focus(id: id)

    registry.handleKeyChar("H")
    #expect(text == "H")
    registry.handleKeyChar("i")
    #expect(text == "Hi")
}

@Test @MainActor func textFieldRegistryBackspace() {
    let registry = TextFieldRegistry.shared
    registry.reset()

    var text = "Hello"
    let binding = Binding(get: { text }, set: { text = $0 })
    let id = registry.register(binding: binding, placeholder: "Name")
    registry.focus(id: id)

    registry.handleBackspace()
    #expect(text == "Hell")
    registry.handleBackspace()
    #expect(text == "Hel")
}

@Test @MainActor func textFieldRegistryBackspaceOnEmpty() {
    let registry = TextFieldRegistry.shared
    registry.reset()

    var text = ""
    let binding = Binding(get: { text }, set: { text = $0 })
    let id = registry.register(binding: binding, placeholder: "Name")
    registry.focus(id: id)

    registry.handleBackspace()
    #expect(text == "")
}

@Test @MainActor func textFieldRegistryNoFocusIgnoresInput() {
    let registry = TextFieldRegistry.shared
    registry.reset()

    var text = ""
    let binding = Binding(get: { text }, set: { text = $0 })
    let _ = registry.register(binding: binding, placeholder: "Name")
    // Don't focus

    registry.handleKeyChar("X")
    #expect(text == "") // No input without focus
}

@Test @MainActor func textFieldRegistryUnfocus() {
    let registry = TextFieldRegistry.shared
    registry.reset()

    var text = ""
    let binding = Binding(get: { text }, set: { text = $0 })
    let id = registry.register(binding: binding, placeholder: "Name")
    registry.focus(id: id)
    registry.handleKeyChar("A")
    #expect(text == "A")

    registry.unfocus()
    registry.handleKeyChar("B")
    #expect(text == "A") // No more input after unfocus
}

@Test @MainActor func textFieldRegistryTabSwitchesFocus() {
    let registry = TextFieldRegistry.shared
    registry.reset()

    var text1 = ""
    var text2 = ""
    let b1 = Binding(get: { text1 }, set: { text1 = $0 })
    let b2 = Binding(get: { text2 }, set: { text2 = $0 })
    let id1 = registry.register(binding: b1, placeholder: "First")
    let _ = registry.register(binding: b2, placeholder: "Second")
    registry.focus(id: id1)

    registry.handleKeyChar("A")
    #expect(text1 == "A")

    registry.handleTab()
    registry.handleKeyChar("B")
    #expect(text1 == "A")
    #expect(text2 == "B")
}

@Test @MainActor func textFieldHitTestFocuses() {
    let registry = TextFieldRegistry.shared
    registry.reset()

    var text = ""
    let binding = Binding(get: { text }, set: { text = $0 })
    let id = registry.register(binding: binding, placeholder: "Name")

    // Simulate layout assigns frame to text field
    registry.setFrame(id: id, frame: LayoutFrame(x: 100, y: 200, width: 200, height: 30))

    // Click inside the text field
    registry.handleClick(x: 150, y: 215)
    #expect(registry.focusedId == id)
}

@Test @MainActor func textFieldHitTestOutsideUnfocuses() {
    let registry = TextFieldRegistry.shared
    registry.reset()

    var text = ""
    let binding = Binding(get: { text }, set: { text = $0 })
    let id = registry.register(binding: binding, placeholder: "Name")
    registry.setFrame(id: id, frame: LayoutFrame(x: 100, y: 200, width: 200, height: 30))
    registry.focus(id: id)
    #expect(registry.focusedId == id)

    // Click outside
    registry.handleClick(x: 50, y: 50)
    #expect(registry.focusedId == nil)
}
