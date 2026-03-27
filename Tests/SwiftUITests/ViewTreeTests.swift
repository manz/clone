import Foundation
import Testing
@testable import SwiftUI

// MARK: - Slider

@Test @MainActor func sliderCreatesSliderNode() {
    let slider = Slider(value: .constant(0.5))
    let node = slider._nodeRepresentation
    if case .slider(let value, let range, _) = node {
        #expect(value == 0.5)
        #expect(range == 0...1)
    } else {
        Issue.record("Expected .slider node, got \(node)")
    }
}

@Test @MainActor func sliderCustomRange() {
    let slider = Slider(value: .constant(5.0), in: 0...10)
    let node = slider._nodeRepresentation
    if case .slider(_, let range, _) = node {
        #expect(range == 0...10)
    } else {
        Issue.record("Expected .slider node")
    }
}

@Test @MainActor func sliderValueFromBinding() {
    var val = 0.7
    let binding = Binding(get: { val }, set: { val = $0 })
    let slider = Slider(value: binding)
    if case .slider(let value, _, _) = slider._nodeRepresentation {
        #expect(value == 0.7)
    } else {
        Issue.record("Expected .slider node")
    }
}

// MARK: - Picker

@Test @MainActor func pickerCreatesPickerNode() {
    let picker = Picker("Sort", selection: .constant("name")) {
        Text("Name")
        Text("Date")
    }
    let node = picker._nodeRepresentation
    if case .picker(_, let label, let children) = node {
        if case .text(let text, _, _, _, _) = label {
            #expect(text == "Sort")
        } else {
            Issue.record("Expected text label")
        }
        #expect(children.count == 2)
    } else {
        Issue.record("Expected .picker node, got \(node)")
    }
}

@Test @MainActor func pickerSelectionReflected() {
    let picker = Picker("Order", selection: .constant("date")) {
        Text("Name")
    }
    if case .picker(let selection, _, _) = picker._nodeRepresentation {
        #expect(selection == "date")
    } else {
        Issue.record("Expected .picker node")
    }
}

// MARK: - Section

@Test @MainActor func sectionWithHeader() {
    let section = Section("Settings") {
        Text("Row")
    }
    let node = section._nodeRepresentation
    guard case .vstack(_, _, let children) = node else {
        Issue.record("Expected .vstack, got \(node)")
        return
    }
    // First child should be the header text
    if case .text(let text, _, _, _, _) = children[0] {
        #expect(text == "Settings")
    } else {
        Issue.record("Expected text header as first child, got \(children[0])")
    }
}

@Test @MainActor func sectionWithoutHeader() {
    let section = Section {
        Text("Row")
    }
    let node = section._nodeRepresentation
    guard case .vstack(_, _, let children) = node else {
        Issue.record("Expected .vstack")
        return
    }
    // No header — first child should be the content directly
    if case .text(let text, _, _, _, _) = children[0] {
        #expect(text == "Row")
    } else {
        Issue.record("Expected text content as first child, got \(children[0])")
    }
}

@Test @MainActor func sectionMultipleRowsHasDividers() {
    let section = Section("Header") {
        Text("A")
        Text("B")
        Text("C")
    }
    let node = section._nodeRepresentation
    guard case .vstack(_, _, let children) = node else {
        Issue.record("Expected .vstack")
        return
    }
    // header + 3 rows + 2 dividers between rows = 6
    #expect(children.count == 6, "Expected header + 3 rows + 2 dividers, got \(children.count)")
}

@Test @MainActor func sectionHeaderAndFooter() {
    let section = Section(
        content: { Text("Body") },
        header: { Text("Top") },
        footer: { Text("Bottom") }
    )
    let node = section._nodeRepresentation
    guard case .vstack(_, _, let children) = node else {
        Issue.record("Expected .vstack")
        return
    }
    // First child: header, last child: footer
    #expect(children.count >= 3, "At least header + content + footer")
    if case .text(let first, _, _, _, _) = children.first! {
        #expect(first == "Top")
    }
    if case .text(let last, _, _, _, _) = children.last! {
        #expect(last == "Bottom")
    }
}

// MARK: - Menu

@Test @MainActor func menuCreatesMenuNode() {
    TapRegistry.shared.clear()
    let menu = Menu("Actions") {
        Button("Copy") {}
        Button("Paste") {}
    }
    let node = menu._nodeRepresentation
    if case .menu(let label, let children) = node {
        #expect(label == "Actions")
        #expect(children.count == 2)
    } else {
        Issue.record("Expected .menu node, got \(node)")
    }
}

@Test @MainActor func menuCustomLabelVariant() {
    TapRegistry.shared.clear()
    let menu = Menu(content: { Button("X") {} }, label: { Text("More") })
    let node = menu._nodeRepresentation
    if case .menu(let label, _) = node {
        // Custom label variant uses hardcoded "Menu" string
        #expect(label == "Menu")
    } else {
        Issue.record("Expected .menu node")
    }
}

// MARK: - Divider

@Test @MainActor func dividerCreatesRect() {
    let divider = Divider()
    let node = divider._nodeRepresentation
    if case .rect(let width, let height, _) = node {
        #expect(width == nil, "Divider width should be nil (fills parent)")
        #expect(height == 1)
    } else {
        Issue.record("Expected .rect node, got \(node)")
    }
}
