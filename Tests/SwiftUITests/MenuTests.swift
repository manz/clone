import Testing
import Foundation
@testable import SwiftUI

@Test @MainActor func commandMenuCollectsItems() {
    MenuRegistry.shared.clear()

    // Simulate a Scene with .commands
    let menus = MenuRegistry.shared.collectFromCommands {
        CommandMenu("File") {
            Button("New") {}
            Button("Open") {}
            Divider()
            Button("Save") {}
        }
        CommandMenu("Edit") {
            Button("Undo") {}
            Button("Redo") {}
        }
    }

    #expect(menus.count == 2)
    #expect(menus[0].title == "File")
    #expect(menus[0].items.count == 4) // New, Open, separator, Save
    #expect(menus[0].items[0].title == "New")
    #expect(menus[0].items[2].isSeparator == true)
    #expect(menus[1].title == "Edit")
    #expect(menus[1].items.count == 2)
}

@Test @MainActor func commandGroupReplacingCollects() {
    MenuRegistry.shared.clear()

    let menus = MenuRegistry.shared.collectFromCommands {
        CommandGroup(replacing: .appTermination) {
            Button("Quit MyApp") {}
        }
    }

    #expect(menus.count == 1)
    #expect(menus[0].items[0].title == "Quit MyApp")
}

@Test @MainActor func commandMenuWithKeyboardShortcut() {
    MenuRegistry.shared.clear()

    let menus = MenuRegistry.shared.collectFromCommands {
        CommandMenu("File") {
            Button("New") {}
                .keyboardShortcut("n", modifiers: .command)
        }
    }

    #expect(menus.count == 1)
    #expect(menus[0].items[0].title == "New")
    // TODO: keyboard shortcuts not yet propagated to menu items
    // #expect(menus[0].items[0].shortcut == "⌘N")
}
