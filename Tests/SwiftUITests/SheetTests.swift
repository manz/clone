import Testing
import Foundation
@testable import SwiftUI

@Test @MainActor func sheetToolbarDoesNotLeakToMainToolbar() {
    TapRegistry.shared.clear()
    WindowState.shared.update(width: 600, height: 400)

    var showSheet = true
    let binding = Binding(get: { showSheet }, set: { showSheet = $0 })

    // Add a main toolbar item directly
    WindowState.shared.addToolbarItems(
        [ToolbarItemData(placement: .primaryAction, node: .text("Main Button", fontSize: 14, color: .primary), sourceKey: "test:main")],
        sourceKey: "test:main"
    )

    // Now evaluate a sheet that has its own toolbar
    let _ = _resolve(Text("Main Content"))
        .sheet(isPresented: binding) {
            Text("Sheet Content")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {}
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {}
                    }
                }
        }

    let mainItems = WindowState.shared.toolbarItems
    let mainLabels = mainItems.compactMap { extractLabel($0.node) }
    #expect(mainLabels.contains("Main Button"), "Main toolbar should have Main Button")
    #expect(!mainLabels.contains("Cancel"), "Sheet Cancel should not leak to main toolbar")
    #expect(!mainLabels.contains("Done"), "Sheet Done should not leak to main toolbar")

    // Sheet toolbar should have Cancel and Done
    let sheetLabels = WindowState.shared.sheetToolbarItems.compactMap { extractLabel($0.node) }
    #expect(sheetLabels.contains("Cancel"), "Sheet toolbar should have Cancel")
    #expect(sheetLabels.contains("Done"), "Sheet toolbar should have Done")
}

@Test @MainActor func sheetDismissActionWorks() {
    TapRegistry.shared.clear()
    WindowState.shared.update(width: 600, height: 400)

    var showSheet = true
    let binding = Binding(get: { showSheet }, set: { showSheet = $0 })

    let _ = _resolve(Text("Main"))
        .sheet(isPresented: binding) {
            Text("Sheet")
        }

    // The sheet should be presented
    #expect(showSheet == true)

    // Simulate clicking the backdrop (which calls dismiss)
    // The dismiss action sets isPresented to false
    // Find backdrop tap — it's the first onTap in the ZStack
    func findFirstTap(_ node: ViewNode) -> UInt64? {
        switch node {
        case .onTap(let id, _): return id
        case .zstack(_, let children):
            for child in children {
                if let id = findFirstTap(child) { return id }
            }
            return nil
        default: return nil
        }
    }

    // The sheet returns a ZStack([self, sheetOverlay])
    // sheetOverlay is a ZStack([backdrop(onTap), centered])
    // We need the backdrop's tap ID
    // Since binding was true, we should find onTap nodes
    // Fire the first one (backdrop)
    if let tapId = findFirstTap(_resolve(Text("Main")).sheet(isPresented: binding) { Text("Sheet") }) {
        TapRegistry.shared.fire(id: tapId)
    }

    #expect(showSheet == false, "Backdrop tap should dismiss the sheet")
}

@Test @MainActor func sheetNotPresentedReturnsPlainView() {
    TapRegistry.shared.clear()
    WindowState.shared.update(width: 600, height: 400)

    var showSheet = false
    let binding = Binding(get: { showSheet }, set: { showSheet = $0 })

    let node = _resolve(Text("Hello"))
        .sheet(isPresented: binding) {
            Text("Sheet Content")
        }

    // When not presented, sheet just returns the original node
    if case .text(let content, _, _, _) = node {
        #expect(content == "Hello")
    } else {
        Issue.record("Expected plain text when sheet not presented, got \(node)")
    }
}

// Helper to extract text from toolbar item nodes
private func extractLabel(_ node: ViewNode) -> String? {
    switch node {
    case .text(let content, _, _, _): return content
    case .onTap(_, let child): return extractLabel(child)
    case .padding(_, let child): return extractLabel(child)
    case .frame(_, _, let child): return extractLabel(child)
    case .hstack(_, _, let children), .vstack(_, _, let children), .zstack(_, let children):
        for child in children {
            if let label = extractLabel(child) { return label }
        }
        return nil
    default: return nil
    }
}
