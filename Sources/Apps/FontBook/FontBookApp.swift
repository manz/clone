import Foundation
import SwiftUI

// MARK: - Colors

#if canImport(AppKit) && !canImport(CloneClient)
import AppKit
var fbBg: Color { Color(nsColor: .windowBackgroundColor) }
var fbSurface: Color { Color(nsColor: .controlBackgroundColor) }
var fbSelected: Color { Color.accentColor.opacity(0.3) }
var fbDivider: Color { Color(nsColor: .separatorColor) }
var fbCardBg: Color { Color(nsColor: .controlBackgroundColor) }
var fbCardBorder: Color { Color(nsColor: .separatorColor) }
#else
let fbBg = Color(red: 0.96, green: 0.96, blue: 0.97)
let fbSurface = Color(red: 1.0, green: 1.0, blue: 1.0)
let fbSelected = Color(red: 0.04, green: 0.52, blue: 1.0, opacity: 0.2)
let fbDivider = Color(red: 0, green: 0, blue: 0, opacity: 0.08)
let fbCardBg = Color(red: 1.0, green: 1.0, blue: 1.0)
let fbCardBorder = Color(red: 0, green: 0, blue: 0, opacity: 0.1)
#endif

// MARK: - State

final class FontBookState {
    var families: [String] = []
    var selectedFamily: String? = nil
    var selectedCategory: String = "All Fonts"

    func loadFonts() {
        families = CTFontManagerCopyAvailableFontFamilyNames()
        if selectedFamily == nil {
            selectedFamily = families.first
        }
    }
}

// MARK: - Sidebar

@MainActor func sidebarView(state: FontBookState, height: CGFloat) -> some View {
    VStack(alignment: .leading, spacing: 0) {
        // Fonts section
        Text("Fonts")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)

        sidebarRow(label: "All Fonts", icon: "grid", selected: state.selectedCategory == "All Fonts") {
            state.selectedCategory = "All Fonts"
        }
        sidebarRow(label: "My Fonts", icon: "person", selected: state.selectedCategory == "My Fonts") {
            state.selectedCategory = "My Fonts"
        }

        Spacer()
    }
}

@MainActor func sidebarRow(label: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
    HStack(spacing: 8) {
        Text(label)
            .font(.system(size: 13))
            .foregroundColor(.primary)
        Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 6)
    .background(selected ? fbSelected : Color(red: 0, green: 0, blue: 0, opacity: 0))
    .onTapGesture { action() }
}

// MARK: - Font card

@MainActor func fontCard(family: String, selected: Bool, cardSize: CGFloat) -> some View {
    VStack(spacing: 4) {
        // Preview area
        VStack {
            Spacer()
            Text("Aa")
                .font(.custom(family, size: 40))
                .foregroundColor(.primary)
            Spacer()
        }
        .frame(width: cardSize, height: cardSize - 30)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selected ? fbSelected : fbCardBg)
        )

        // Family name
        Text(family)
            .font(.system(size: 10))
            .foregroundColor(.primary)
    }
    .frame(width: cardSize)
}

// MARK: - Font grid

/// Group families into rows for grid display.
func gridRows(families: [String], columns: Int) -> [[String]] {
    var rows: [[String]] = []
    var row: [String] = []
    for family in families {
        row.append(family)
        if row.count == columns {
            rows.append(row)
            row = []
        }
    }
    if !row.isEmpty { rows.append(row) }
    return rows
}

@MainActor func fontGridView(state: FontBookState, width: CGFloat, height: CGFloat) -> some View {
    let cardSize: CGFloat = 130
    let spacing: CGFloat = 16
    let padding: CGFloat = 20
    let availableWidth = width - padding * 2
    let columns = max(1, Int(availableWidth / (cardSize + spacing)))
    let rows = gridRows(families: state.families, columns: columns)

    return VStack(alignment: .leading, spacing: 0) {
        // Header
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("All Fonts")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                Text("\(state.families.count) font families")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, padding)
        .padding(.vertical, 12)

        Rectangle().fill(fbDivider).frame(height: 1)

        // Grid
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: spacing) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, family in
                            fontCard(
                                family: family,
                                selected: state.selectedFamily == family,
                                cardSize: cardSize
                            )
                            .onTapGesture {
                                state.selectedFamily = family
                            }
                        }
                        Spacer()
                    }
                }
            }
            .padding(padding)
        }
    }
}

// MARK: - Root

@MainActor func fontBookRoot(state: FontBookState, width: CGFloat, height: CGFloat) -> some View {
    let sidebarWidth: CGFloat = 180

    return HStack(spacing: 0) {
        sidebarView(state: state, height: height)
            .frame(width: sidebarWidth, height: height)
            .background(fbBg)

        Rectangle().fill(fbDivider).frame(width: 1)

        fontGridView(state: state, width: width - sidebarWidth - 1, height: height)
            .frame(width: width - sidebarWidth - 1, height: height)
            .background(fbSurface)
    }
}

// MARK: - App

@main
struct FontBookApp: App {
    let state = FontBookState()

    var body: some Scene {
        WindowGroup("Font Book") {
            GeometryReader { proxy in
                fontBookRoot(state: state, width: proxy.size.width, height: proxy.size.height)
            }
            .onAppear { state.loadFonts() }
        }
    }

    #if canImport(CloneClient)
    var configuration: WindowConfiguration {
        WindowConfiguration(title: "Font Book", width: 900, height: 650, role: .window)
    }
    #endif
}
