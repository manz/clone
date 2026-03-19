import Foundation
import SwiftUI

final class MenuBarState {
    var focusedAppName = "Finder"
}

let menuItems = ["File", "Edit", "View", "Window", "Help"]

func menuBarView(state: MenuBarState) -> some View {
    let menuTextColor: Color = .primary

    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    let clock = formatter.string(from: Date())

    var children: [ViewNode] = []

    // Apple logo placeholder
    children.append(
        Text("\u{F8FF}")
            .font(.system(size: 14))
            .foregroundColor(.primary)
    )

    // Focused app name (bold)
    children.append(
        Text(state.focusedAppName)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.primary)
    )

    // Menu items
    for item in menuItems {
        children.append(
            Text(item)
                .font(.system(size: 13))
                .foregroundColor(menuTextColor)
        )
    }

    // Spacer pushes clock to the right
    children.append(Spacer())

    // Clock (right-aligned)
    children.append(
        Text(clock)
            .font(.system(size: 13))
            .foregroundColor(.primary)
    )

    // Dynamic children — can't use ViewBuilder
    return ViewNode.hstack(alignment: .center, spacing: 16, children: children)
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(WindowChrome.menuBar)
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
