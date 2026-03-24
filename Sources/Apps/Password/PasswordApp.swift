import Foundation
import SwiftUI

// MARK: - Color palette

#if canImport(AppKit) && !canImport(CloneClient)
import AppKit
var bgBase: Color { Color(nsColor: .windowBackgroundColor) }
var bgSurface: Color { Color(nsColor: .controlBackgroundColor) }
var bgOverlay: Color { Color(nsColor: .unemphasizedSelectedContentBackgroundColor) }
var bgSelected: Color { Color.accentColor.opacity(0.3) }
var bgHover: Color { Color(nsColor: .unemphasizedSelectedContentBackgroundColor).opacity(0.5) }
var dividerColor: Color { Color(nsColor: .separatorColor) }
#else
let bgBase = Color(red: 0.96, green: 0.96, blue: 0.97)
let bgSurface = Color(red: 1.0, green: 1.0, blue: 1.0)
let bgOverlay = Color(red: 0.93, green: 0.93, blue: 0.94)
let bgSelected = Color(red: 0.04, green: 0.52, blue: 1.0, opacity: 0.2)
let bgHover = Color(red: 0, green: 0, blue: 0, opacity: 0.04)
let dividerColor = Color(red: 0, green: 0, blue: 0, opacity: 0.08)
#endif

// MARK: - Data model

struct PasswordCategory {
    let name: String
    let icon: String
    let color: Color
}

let passwordCategories: [PasswordCategory] = [
    PasswordCategory(name: "All Items", icon: "key.fill", color: .gray),
    PasswordCategory(name: "Passwords", icon: "lock.fill", color: .blue),
    PasswordCategory(name: "Wi-Fi", icon: "wifi", color: .green),
    PasswordCategory(name: "Passkeys", icon: "person.badge.key.fill", color: .purple),
    PasswordCategory(name: "Notes", icon: "note.text", color: .orange),
]

struct PasswordItem {
    let id: Int
    let service: String
    let account: String
    let password: String
    let website: String
    let category: String
    let created: String
    let modified: String
}

let sampleItems: [PasswordItem] = [
    PasswordItem(id: 0, service: "GitHub", account: "user@example.com", password: "s3cr3tGH!", website: "github.com", category: "Passwords", created: "2025-01-15", modified: "2025-03-20"),
    PasswordItem(id: 1, service: "Google", account: "user@gmail.com", password: "gM@il2025", website: "google.com", category: "Passwords", created: "2024-11-02", modified: "2025-02-18"),
    PasswordItem(id: 2, service: "Home Wi-Fi", account: "HomeNetwork", password: "wifipass1", website: "", category: "Wi-Fi", created: "2025-02-01", modified: "2025-02-01"),
    PasswordItem(id: 3, service: "Office Wi-Fi", account: "CorpNet", password: "c0rpWifi!", website: "", category: "Wi-Fi", created: "2025-01-10", modified: "2025-01-10"),
    PasswordItem(id: 4, service: "Secure Note", account: "Recovery codes", password: "ABC-DEF-GHI", website: "", category: "Notes", created: "2025-03-01", modified: "2025-03-01"),
]

// MARK: - State

final class PasswordState {
    var selectedCategory: String = "All Items"
    var selectedItemId: Int = 0
    var showPassword: Bool = false
    var mouseX: CGFloat = 0
    var mouseY: CGFloat = 0

    let sidebarWidth: CGFloat = 200
    let listWidth: CGFloat = 240
    let rowHeight: CGFloat = 44
    let categoryRowHeight: CGFloat = 28
    let headerHeight: CGFloat = 40

    func filteredItems() -> [PasswordItem] {
        sampleItems.filter { item in
            if selectedCategory != "All Items" && item.category != selectedCategory {
                return false
            }
            return true
        }
    }
}

// MARK: - Sidebar category row

@MainActor private func categoryRow(
    state: PasswordState,
    cat: PasswordCategory,
    flatIndex: Int
) -> some View {
    let isSelected = state.selectedCategory == cat.name
    let rowY = state.headerHeight + CGFloat(flatIndex) * state.categoryRowHeight
    let isHovered = state.mouseX < state.sidebarWidth
        && state.mouseY >= rowY && state.mouseY < rowY + state.categoryRowHeight

    let bg: Color = isSelected ? bgSelected : (isHovered ? bgHover : .clear)

    let content = HStack(spacing: 8) {
        Image(systemName: cat.icon)
            .foregroundColor(cat.color)
            .frame(width: 18, height: 18)
        Text(cat.name).font(.system(size: 13)).foregroundColor(.primary)
        Spacer()
    }
    .padding(.horizontal, 8)

    return ZStack {
        RoundedRectangle(cornerRadius: 5).fill(bg).frame(height: state.categoryRowHeight)
        content
    }.frame(height: state.categoryRowHeight)
}

// MARK: - Sidebar

@MainActor private func sidebarView(state: PasswordState, height: CGFloat) -> some View {
    let content = VStack(alignment: .leading, spacing: 0) {
        Text("Passwords")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(EdgeInsets(top: 12, leading: 12, bottom: 8, trailing: 12))

        ForEach(Array(passwordCategories.enumerated()), id: \.offset) { i, cat in
            categoryRow(state: state, cat: cat, flatIndex: i)
        }
        Spacer()
    }
    return ZStack {
        Rectangle().fill(bgBase).frame(width: state.sidebarWidth, height: height)
        content
    }.frame(width: state.sidebarWidth, height: height)
}

// MARK: - Item list row

@MainActor private func itemRow(
    state: PasswordState,
    item: PasswordItem,
    rowIndex: Int
) -> some View {
    let isSelected = state.selectedItemId == item.id
    let rowY = state.headerHeight + CGFloat(rowIndex) * state.rowHeight
    let isHovered = state.mouseX >= state.sidebarWidth
        && state.mouseX < state.sidebarWidth + state.listWidth
        && state.mouseY >= rowY && state.mouseY < rowY + state.rowHeight

    let bg: Color = isSelected ? bgSelected : (isHovered ? bgHover : .clear)

    let content = VStack(alignment: .leading, spacing: 2) {
        Text(item.service).font(.system(size: 13, weight: .medium)).foregroundColor(.primary)
        Text(item.account).font(.system(size: 11)).foregroundColor(.secondary)
    }
    .padding(.horizontal, 12)

    return ZStack {
        Rectangle().fill(bg).frame(width: state.listWidth, height: state.rowHeight)
        content
    }.frame(width: state.listWidth, height: state.rowHeight)
}

// MARK: - Item list

@MainActor private func itemListView(state: PasswordState, height: CGFloat) -> some View {
    let items = state.filteredItems()

    let content = VStack(alignment: .leading, spacing: 0) {
        Text("\(items.count) items")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .padding(EdgeInsets(top: 12, leading: 12, bottom: 8, trailing: 12))

        ForEach(Array(items.enumerated()), id: \.offset) { i, item in
            itemRow(state: state, item: item, rowIndex: i)
        }
        Spacer()
    }
    return ZStack {
        Rectangle().fill(bgSurface).frame(width: state.listWidth, height: height)
        content
    }.frame(width: state.listWidth, height: height)
}

// MARK: - Detail field row

@MainActor private func fieldRow(label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(label).font(.system(size: 11)).foregroundColor(.secondary)
        Text(value).font(.system(size: 13)).foregroundColor(.primary)
    }
    .padding(.vertical, 4)
}

// MARK: - Detail pane

@MainActor private func detailView(state: PasswordState, width: CGFloat, height: CGFloat) -> some View {
    let detailWidth = width - state.sidebarWidth - state.listWidth - 2 // 2 for dividers
    let items = state.filteredItems()
    let selected = items.first(where: { $0.id == state.selectedItemId })

    let content = VStack(alignment: .leading, spacing: 0) {
        if let item = selected {
            Text(item.service)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.bottom, 16)

            fieldRow(label: "Username", value: item.account)
            fieldRow(label: "Password", value: state.showPassword ? item.password : "••••••••")
            if !item.website.isEmpty {
                fieldRow(label: "Website", value: item.website)
            }
            fieldRow(label: "Created", value: item.created)
            fieldRow(label: "Modified", value: item.modified)
        } else {
            Spacer()
            Text("No item selected")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        Spacer()
    }
    .padding(24)

    return ZStack {
        Rectangle().fill(bgSurface).frame(width: detailWidth, height: height)
        content
    }.frame(width: detailWidth, height: height)
}

// MARK: - Root view

@MainActor func passwordView(state: PasswordState, width: CGFloat, height: CGFloat) -> some View {
    HStack(spacing: 0) {
        sidebarView(state: state, height: height)
        Rectangle().fill(dividerColor).frame(width: 1, height: height)
        itemListView(state: state, height: height)
        Rectangle().fill(dividerColor).frame(width: 1, height: height)
        detailView(state: state, width: width, height: height)
    }
}

// MARK: - App

@main
struct PasswordApp: App {
    let state = PasswordState()

    var body: some Scene {
        WindowGroup("Passwords") {
            #if canImport(AppKit) && !canImport(CloneClient)
            GeometryReader { proxy in
                passwordView(state: state, width: proxy.size.width, height: proxy.size.height)
            }
            #else
            passwordView(state: state, width: WindowState.shared.width, height: WindowState.shared.height)
            #endif
        }
    }

    #if canImport(CloneClient)
    var configuration: WindowConfiguration {
        WindowConfiguration(title: "Passwords", width: 800, height: 550, role: .window)
    }

    func onPointerMove(x: CGFloat, y: CGFloat) {
        state.mouseX = x
        state.mouseY = y
    }

    func onPointerButton(button: UInt32, pressed: Bool, x: CGFloat, y: CGFloat) {
        guard button == 0 && pressed else { return }

        if x < state.sidebarWidth {
            for i in 0..<passwordCategories.count {
                let rowY = state.headerHeight + CGFloat(i) * state.categoryRowHeight
                if y >= rowY && y < rowY + state.categoryRowHeight {
                    state.selectedCategory = passwordCategories[i].name
                    break
                }
            }
            return
        }

        let items = state.filteredItems()
        if x >= state.sidebarWidth && x < state.sidebarWidth + state.listWidth {
            for i in 0..<items.count {
                let rowY = state.headerHeight + CGFloat(i) * state.rowHeight
                if y >= rowY && y < rowY + state.rowHeight {
                    state.selectedItemId = items[i].id
                    break
                }
            }
        }
    }
    #endif
}
