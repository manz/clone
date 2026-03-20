import Foundation
import SwiftUI

final class MenuBarState {
    var focusedAppName = "Finder"
}

let menuItems = ["File", "Edit", "View", "Window", "Help"]

@MainActor func menuBarView(state: MenuBarState) -> some View {
    let menuTextColor: Color = .primary

    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    let clock = formatter.string(from: Date())

    return HStack(alignment: .center, spacing: 16) {
        // Apple logo placeholder
        Text("\u{F8FF}")
            .font(.system(size: 14))
            .foregroundColor(.primary)

        // Focused app name (bold)
        Text(state.focusedAppName)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.primary)

        // Menu items
        ForEach(menuItems, id: \.self) { item in
            Text(item)
                .font(.system(size: 13))
                .foregroundColor(menuTextColor)
        }

        // Spacer pushes clock to the right
        Spacer()

        // Clock (right-aligned)
        Text(clock)
            .font(.system(size: 13))
            .foregroundColor(.primary)
    }
    .padding(.horizontal, 12)
    .frame(height: 24)
    .background(Color.adaptive(dark: Color(red: 0.1, green: 0.1, blue: 0.1, opacity: 0.5),
                               light: Color(red: 0.96, green: 0.96, blue: 0.96, opacity: 0.8)))
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
