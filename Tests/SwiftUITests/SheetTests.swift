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

    #expect(showSheet == true)
    #expect(WindowState.shared.activeSheetOverlay != nil)

    // Find backdrop tap in the window-level overlay
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

    if let overlay = WindowState.shared.activeSheetOverlay,
       let tapId = findFirstTap(overlay) {
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

    // When not presented, sheet returns the original node and no overlay
    if case .text(let content, _, _, _) = node {
        #expect(content == "Hello")
    } else {
        Issue.record("Expected plain text when sheet not presented, got \(node)")
    }
    #expect(WindowState.shared.activeSheetOverlay == nil)
}

@Test @MainActor func sheetPresentedRegistersOverlay() {
    TapRegistry.shared.clear()
    WindowState.shared.update(width: 600, height: 400)

    var showSheet = true
    let binding = Binding(get: { showSheet }, set: { showSheet = $0 })

    let _ = _resolve(Text("Main"))
        .sheet(isPresented: binding) {
            Text("Sheet Content")
        }

    #expect(WindowState.shared.activeSheetOverlay != nil, "Sheet should register window-level overlay")
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
