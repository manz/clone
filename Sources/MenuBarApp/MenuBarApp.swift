import Foundation
import SwiftUI
import CloneClient
import CloneProtocol

final class MenuBarState {
    var focusedAppName = "Finder"
}

let menuItems = ["File", "Edit", "View", "Window", "Help"]

func menuBarView(state: MenuBarState) -> ViewNode {
    let menuTextColor: Color = .text

    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    let clock = formatter.string(from: Date())

    var children: [ViewNode] = []

    // Apple logo placeholder
    children.append(
        Text("\u{F8FF}")
            .fontSize(14)
            .foregroundColor(.white)
    )

    // Focused app name (bold)
    children.append(
        Text(state.focusedAppName)
            .fontSize(13)
            .bold()
            .foregroundColor(.white)
    )

    // Menu items
    for item in menuItems {
        children.append(
            Text(item)
                .fontSize(13)
                .foregroundColor(menuTextColor)
        )
    }

    // Spacer pushes clock to the right
    children.append(Spacer())

    // Clock (right-aligned)
    children.append(
        Text(clock)
            .fontSize(13)
            .foregroundColor(.white)
    )

    return ViewNode.hstack(alignment: .center, spacing: 16, children: children)
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(.menuBarBackground)
}

@main
struct MenuBarApp: App {
    let state = MenuBarState()

    var body: some Scene {
        WindowGroup("MenuBar") {
            menuBarView(state: state)
        }
    }

    var configuration: WindowConfiguration {
        WindowConfiguration(title: "MenuBar", width: 1280, height: 24, role: .menubar)
    }

    func onFocusedApp(name: String) {
        state.focusedAppName = name
    }
}
