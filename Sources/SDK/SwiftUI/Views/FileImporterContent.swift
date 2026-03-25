import Foundation
import UniformTypeIdentifiers

/// Internal view for .fileImporter() — presented as a sheet.
/// Uses the shared FileBrowserState + FileListView.
@MainActor
struct _FileImporterContent: View {
    let extensions: [String]
    let dismiss: () -> Void
    let onCompletion: @MainActor (Result<[URL], Error>) -> Void

    @StateObject private var browser = FileBrowserState()

    init(extensions: [String], dismiss: @escaping () -> Void, onCompletion: @escaping @MainActor (Result<[URL], Error>) -> Void) {
        self.extensions = extensions
        self.dismiss = dismiss
        self.onCompletion = onCompletion
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Navigation toolbar
            HStack(spacing: 8) {
                FileBrowserNavButtons(state: browser)
                Spacer()
                Text(browser.shortPath)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))

            Divider()

            // Split: sidebar + file list
            HStack(alignment: .top, spacing: 0) {
                FileBrowserSidebar(state: browser)
                    .frame(width: 160)
                Divider()
                FileListView(state: browser, onOpen: { entry in
                    if entry.isDirectory {
                        browser.navigateTo(entry.id)
                    }
                })
            }

            Divider()

            // Footer: Cancel + Open
            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Open") {
                    if let entry = browser.selectedEntry, !entry.isDirectory {
                        dismiss()
                        onCompletion(.success([URL(fileURLWithPath: entry.id)]))
                    } else if let entry = browser.selectedEntry, entry.isDirectory {
                        browser.navigateTo(entry.id)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Open") {
                    if let entry = browser.selectedEntry, !entry.isDirectory {
                        dismiss()
                        onCompletion(.success([URL(fileURLWithPath: entry.id)]))
                    }
                }
            }
        }
    }
}
