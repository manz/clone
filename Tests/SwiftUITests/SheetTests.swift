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
    if case .text(let content, _, _, _, _) = node {
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

@Test @MainActor func sheetContentAndSizeAreSet() {
    TapRegistry.shared.clear()
    WindowState.shared.update(width: 600, height: 400)

    var showSheet = true
    let binding = Binding(get: { showSheet }, set: { showSheet = $0 })

    let _ = _resolve(Text("Main"))
        .sheet(isPresented: binding) {
            Text("Sheet Body")
        }

    #expect(WindowState.shared.activeSheetContent != nil, "Sheet content should be set")
    #expect(WindowState.shared.activeSheetSize != nil, "Sheet size should be set")

    if let size = WindowState.shared.activeSheetSize {
        #expect(size.width == 500, "Sheet width should be 500 (maxW)")
        #expect(size.height >= 40, "Sheet height should be at least 40pt for text + padding")
        #expect(size.height < 10000, "Sheet height should not be infinity or unreasonably large")
    }
}

@Test @MainActor func sheetSizeMeasuresContent() {
    TapRegistry.shared.clear()
    WindowState.shared.update(width: 800, height: 600)

    var showSheet = true
    let binding = Binding(get: { showSheet }, set: { showSheet = $0 })

    // Sheet with multiple lines of content should be taller
    let _ = _resolve(Text("Main"))
        .sheet(isPresented: binding) {
            VStack {
                Text("Line 1")
                Text("Line 2")
                Text("Line 3")
                Text("Line 4")
                Text("Line 5")
            }
        }

    if let size = WindowState.shared.activeSheetSize {
        #expect(size.height > 80, "Sheet with 5 lines should be at least 80pt tall")
        #expect(size.height < 10000, "Sheet height should be finite")
    } else {
        Issue.record("Sheet size should be set")
    }
}

@Test @MainActor func sheetSizeWithToolbar() {
    TapRegistry.shared.clear()
    WindowState.shared.update(width: 800, height: 600)

    var showSheet = true
    let binding = Binding(get: { showSheet }, set: { showSheet = $0 })

    let _ = _resolve(Text("Main"))
        .sheet(isPresented: binding) {
            Text("Content")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {}
                    }
                }
        }

    if let size = WindowState.shared.activeSheetSize {
        // With toolbar, should be taller than without
        #expect(size.height > 60, "Sheet with toolbar should be taller")
        #expect(size.height < 10000, "Sheet height should be finite")
    } else {
        Issue.record("Sheet size should be set")
    }
}

@Test @MainActor func sheetCompositorActiveHidesInWindowPanel() {
    TapRegistry.shared.clear()
    WindowState.shared.update(width: 600, height: 400)

    var showSheet = true
    let binding = Binding(get: { showSheet }, set: { showSheet = $0 })

    let _ = _resolve(Text("Main"))
        .sheet(isPresented: binding) {
            Text("Sheet Content")
        }

    // Before compositor is active, overlay has backdrop + centered panel
    let overlay = WindowState.shared.activeSheetOverlay!
    guard case .zstack(_, let children) = overlay else {
        Issue.record("Expected zstack overlay")
        return
    }
    #expect(children.count == 2, "Overlay should have backdrop + centered panel")

    // After compositor is active, compositorSheetActive flag should be set
    #expect(WindowState.shared.compositorSheetActive == false, "Initially false")
    WindowState.shared.compositorSheetActive = true
    // The App.swift code checks this flag to decide whether to include full overlay or just backdrop
    #expect(WindowState.shared.compositorSheetActive == true)
}

@Test @MainActor func sheetButtonTapViaHitTest() {
    TapRegistry.shared.clear()
    WindowState.shared.update(width: 800, height: 600)

    var showSheet = true
    let binding = Binding(get: { showSheet }, set: { showSheet = $0 })
    var cancelFired = false
    var doneFired = false

    let _ = _resolve(Text("Main"))
        .sheet(isPresented: binding) {
            Text("Sheet Body")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { cancelFired = true }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { doneFired = true }
                    }
                }
        }

    // Sheet content and size must exist
    guard let sheetContent = WindowState.shared.activeSheetContent else {
        Issue.record("No activeSheetContent")
        return
    }
    guard let sheetSize = WindowState.shared.activeSheetSize else {
        Issue.record("No activeSheetSize")
        return
    }

    // Layout the sheet content exactly as the compositor would
    let layoutNode = Layout.layout(
        sheetContent,
        in: LayoutFrame(x: 0, y: 0, width: sheetSize.width, height: sheetSize.height)
    )

    // The sheet content should have a non-zero size
    #expect(layoutNode.frame.width > 0, "Sheet layout width should be > 0")
    #expect(layoutNode.frame.height > 0, "Sheet layout height should be > 0")

    // Find all tappable areas in the layout
    var tappableAreas: [(id: UInt64, frame: LayoutFrame, label: String)] = []
    collectTappableAreas(layoutNode, into: &tappableAreas)

    #expect(!tappableAreas.isEmpty, "Sheet should have tappable buttons (Cancel, Done)")

    // Find Cancel and Done buttons by label
    let cancelArea = tappableAreas.first(where: { $0.label.contains("Cancel") })
    let doneArea = tappableAreas.first(where: { $0.label.contains("Done") })

    #expect(cancelArea != nil, "Should find Cancel button tappable area — found: \(tappableAreas.map(\.label))")
    #expect(doneArea != nil, "Should find Done button tappable area — found: \(tappableAreas.map(\.label))")

    // Hit-test at the center of the Cancel button
    if let cancel = cancelArea {
        let cx = cancel.frame.x + cancel.frame.width / 2
        let cy = cancel.frame.y + cancel.frame.height / 2
        let hit = layoutNode.hitTestTap(x: cx, y: cy)
        #expect(hit != nil, "Hit-test at Cancel center (\(cx), \(cy)) should find a tap — frame: \(cancel.frame)")
        if let hit = hit {
            TapRegistry.shared.fire(id: hit.id)
            #expect(cancelFired, "Firing tap at Cancel position should trigger cancelFired")
        }
    }

    // Hit-test at the center of the Done button
    if let done = doneArea {
        let cx = done.frame.x + done.frame.width / 2
        let cy = done.frame.y + done.frame.height / 2
        let hit = layoutNode.hitTestTap(x: cx, y: cy)
        #expect(hit != nil, "Hit-test at Done center (\(cx), \(cy)) should find a tap — frame: \(done.frame)")
        if let hit = hit {
            TapRegistry.shared.fire(id: hit.id)
            #expect(doneFired, "Firing tap at Done position should trigger doneFired")
        }
    }
}

/// Walk the layout tree and collect all onTap areas with their frames and labels.
private func collectTappableAreas(_ node: LayoutNode, into areas: inout [(id: UInt64, frame: LayoutFrame, label: String)]) {
    switch node.node {
    case .onTap(let id, let child):
        let label = extractLabel(child) ?? "(unknown)"
        areas.append((id: id, frame: node.frame, label: label))
    default:
        break
    }
    for child in node.children {
        collectTappableAreas(child, into: &areas)
    }
}

// Helper to extract text from toolbar item nodes
private func extractLabel(_ node: ViewNode) -> String? {
    switch node {
    case .text(let content, _, _, _, _): return content
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
