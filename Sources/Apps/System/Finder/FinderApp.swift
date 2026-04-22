import Foundation
import SwiftUI
import AppKit

// MARK: - App

@main
struct FinderApp: App {
    @StateObject private var browser = FileBrowserState()

    var body: some Scene {
        WindowGroup("Finder") {
            NavigationSplitView {
                FileBrowserSidebar(state: browser)
            } detail: {
                FileListView(state: browser, onOpen: { entry in
                    if entry.isAppBundle {
                        NSWorkspace.shared.open(URL(fileURLWithPath: entry.id))
                    } else if entry.isDirectory {
                        browser.navigateTo(entry.id)
                    } else {
                        NSWorkspace.shared.open(URL(fileURLWithPath: entry.id))
                    }
                })
                .contextMenu {
                    Button("New Folder") { }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    FileBrowserNavButtons(state: browser)
                }
                ToolbarItem(placement: .principal) {
                    Text(browser.shortPath)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Finder — \(browser.shortPath)")
        }
        .commands {
            CommandMenu("File") {
                Button("New Folder") { }
            }
            CommandMenu("Go") {
                Button("Back") { browser.goBack() }
                Button("Forward") { browser.goForward() }
                Button("Home") { browser.navigateTo(NSHomeDirectory()) }
            }
        }
    }
}
