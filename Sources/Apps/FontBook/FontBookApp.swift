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
#else
let fbBg = Color(red: 0.96, green: 0.96, blue: 0.97)
let fbSurface = Color(red: 1.0, green: 1.0, blue: 1.0)
let fbSelected = Color(red: 0.04, green: 0.52, blue: 1.0, opacity: 0.2)
let fbDivider = Color(red: 0, green: 0, blue: 0, opacity: 0.08)
let fbCardBg = Color(red: 1.0, green: 1.0, blue: 1.0)
#endif

// MARK: - State

final class FontBookState: ObservableObject {
    @Published var families: [String] = []
    @Published var selectedFamily: String? = nil
    @Published var detailFamily: String? = nil

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
        Text("Fonts")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)

        HStack(spacing: 8) {
            Text("All Fonts")
                .font(.system(size: 13))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(fbSelected)

        Spacer()
    }
}

// MARK: - Font card

@MainActor func fontCard(family: String, selected: Bool, cardSize: CGFloat) -> some View {
    VStack(spacing: 4) {
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

        Text(family)
            .font(.system(size: 10))
            .foregroundColor(.primary)
    }
    .frame(width: cardSize)
}

// MARK: - Font grid

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
                                state.detailFamily = family
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

// MARK: - Detail view (specimen)

let uppercaseLetters = "A B C D E F G H I J K L M N O P Q R S T U V W X Y Z"
let lowercaseLetters = "a b c d e f g h i j k l m n o p q r s t u v w x y z"
let digits = "1 2 3 4 5 6 7 8 9 0"

@MainActor func fontDetailView(state: FontBookState, family: String, width: CGFloat, height: CGFloat) -> some View {
    VStack(alignment: .leading, spacing: 0) {
        // Header with back button
        HStack(spacing: 12) {
            Text("<")
                .font(.system(size: 18))
                .foregroundColor(.blue)
                .onTapGesture { state.detailFamily = nil }
            VStack(alignment: .leading, spacing: 2) {
                Text(family)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                Text("1 style")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)

        Rectangle().fill(fbDivider).frame(height: 1)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Preview section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text(uppercaseLetters)
                        .font(.custom(family, size: 32))
                        .foregroundColor(.primary)
                    Text(lowercaseLetters)
                        .font(.custom(family, size: 32))
                        .foregroundColor(.primary)
                    Text(digits)
                        .font(.custom(family, size: 32))
                        .foregroundColor(.primary)
                }

                Rectangle().fill(fbDivider).frame(height: 1)

                // Sizes section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sizes")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    ForEach([10, 12, 14, 18, 24, 36, 48, 72], id: \.self) { size in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(size)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(width: 24)
                            Text("The quick brown fox jumps over the lazy dog")
                                .font(.custom(family, size: CGFloat(size)))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Root

@MainActor func fontBookRoot(state: FontBookState, width: CGFloat, height: CGFloat) -> some View {
    let sidebarWidth: CGFloat = 180
    let contentWidth = width - sidebarWidth - 1

    return HStack(spacing: 0) {
        sidebarView(state: state, height: height)
            .frame(width: sidebarWidth, height: height)
            .background(fbBg)

        Rectangle().fill(fbDivider).frame(width: 1)

        ZStack {
            fontGridView(state: state, width: contentWidth, height: height)
                .frame(width: contentWidth, height: height)
                .opacity(state.detailFamily == nil ? 1 : 0)

            if let detail = state.detailFamily {
                fontDetailView(state: state, family: detail, width: contentWidth, height: height)
                    .frame(width: contentWidth, height: height)
            }
        }
        .background(fbSurface)
    }
}

// MARK: - App

@main
struct FontBookApp: App {
    @StateObject private var state = FontBookState()

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
