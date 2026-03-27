import Foundation
import SwiftUI

// MARK: - Colors

#if canImport(AppKit) && !canImport(CloneClient)
import AppKit
var fbBg: Color { Color(nsColor: .windowBackgroundColor) }
var fbSurface: Color { Color(nsColor: .controlBackgroundColor) }
var fbSelected: Color { Color.accentColor.opacity(0.3) }
var fbDivider: Color { Color(nsColor: .separatorColor) }
#else
let fbBg = Color(red: 0.96, green: 0.96, blue: 0.97)
let fbSurface = Color(red: 1.0, green: 1.0, blue: 1.0)
let fbSelected = Color(red: 0.04, green: 0.52, blue: 1.0, opacity: 0.2)
let fbDivider = Color(red: 0, green: 0, blue: 0, opacity: 0.08)
#endif

// MARK: - State

final class FontBookState {
    var families: [String] = []
    var selectedFamily: String? = nil
    var previewText: String = "The quick brown fox jumps over the lazy dog."
    var previewSize: CGFloat = 24

    func loadFonts() {
        families = CTFontManagerCopyAvailableFontFamilyNames()
        if selectedFamily == nil {
            selectedFamily = families.first
        }
    }
}

// MARK: - Views

@MainActor func fontListView(state: FontBookState, listWidth: CGFloat, listHeight: CGFloat) -> some View {
    ScrollView {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(state.families.enumerated()), id: \.offset) { _, family in
                let isSelected = state.selectedFamily == family
                HStack {
                    Text(family)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? fbSelected : Color(red: 0, green: 0, blue: 0, opacity: 0))
                .onTapGesture {
                    state.selectedFamily = family
                }
            }
        }
    }
}

@MainActor func fontPreviewView(state: FontBookState, width: CGFloat, height: CGFloat) -> some View {
    VStack(alignment: .leading, spacing: 16) {
        if let family = state.selectedFamily {
            Text(family)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)

            Text(state.previewText)
                .font(.custom(family, size: state.previewSize))
                .foregroundColor(.primary)

            Rectangle().fill(fbDivider).frame(height: 1)

            Text("Sizes")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach([12, 14, 18, 24, 36, 48, 72], id: \.self) { size in
                    HStack(alignment: .top) {
                        Text("\(size)pt")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: 36)
                        Text(state.previewText)
                            .font(.custom(family, size: CGFloat(size)))
                            .foregroundColor(.primary)
                    }
                }
            }
        } else {
            Text("No font selected")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        Spacer()
    }
    .padding(16)
}

@MainActor func fontBookRoot(state: FontBookState, width: CGFloat, height: CGFloat) -> some View {
    let sidebarWidth: CGFloat = 220

    return HStack(spacing: 0) {
        // Sidebar — font list
        VStack(spacing: 0) {
            HStack {
                Text("\(state.families.count) fonts")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Rectangle().fill(fbDivider).frame(height: 1)

            fontListView(state: state, listWidth: sidebarWidth, listHeight: height - 30)
        }
        .frame(width: sidebarWidth)
        .background(fbBg)

        Rectangle().fill(fbDivider).frame(width: 1)

        // Detail — preview
        fontPreviewView(state: state, width: width - sidebarWidth - 1, height: height)
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
        WindowConfiguration(title: "Font Book", width: 800, height: 600, role: .window)
    }
    #endif
}
