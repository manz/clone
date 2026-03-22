import Testing
@testable import SwiftUI

// MARK: - Smoke tests for new SwiftUI constructs

@Test @MainActor func importSwiftUIAndCreateText() {
    let node = _resolve(Text("hello"))
    if case .text(let content, _, _, _) = node {
        #expect(content == "hello")
    } else {
        Issue.record("Expected text node")
    }
}

@Test @MainActor func colorAsView() {
    let body = _resolve(Color.blue)
    if case .rect(let w, let h, let fill) = body {
        #expect(w == nil)
        #expect(h == nil)
        #expect(fill == .blue)
    } else {
        Issue.record("Expected rect from Color.body")
    }
}

@Test @MainActor func buttonWithStringLabel() {
    let node = _resolve(Button("Tap") {})
    if case .onTap(_, let child) = node {
        if case .text(let content, _, let color, _) = child {
            #expect(content == "Tap")
            #expect(color == .blue)
        } else {
            Issue.record("Expected text child in Button")
        }
    } else {
        Issue.record("Expected onTap wrapper from Button")
    }
}

@Test @MainActor func buttonWithCustomLabel() {
    let node = _resolve(Button(action: {}) {
        Text("Custom")
    })
    if case .onTap(_, let child) = node {
        if case .text(let content, _, _, _) = child {
            #expect(content == "Custom")
        } else {
            Issue.record("Expected text child in Button")
        }
    } else {
        Issue.record("Expected onTap wrapper from Button")
    }
}

@Test @MainActor func scrollViewCreatesNode() {
    let node = _resolve(ScrollView {
        Text("Item 1")
        Text("Item 2")
    })
    if case .scrollView(let axis, let children) = node {
        #expect(axis == .vertical)
        #expect(children.count >= 1)
    } else {
        Issue.record("Expected scrollView node")
    }
}

@Test @MainActor func listCreatesNode() {
    let node = _resolve(List {
        Text("Row 1")
        Text("Row 2")
    })
    if case .list(let children) = node {
        #expect(children.count >= 1)
    } else {
        Issue.record("Expected list node")
    }
}

@Test @MainActor func imageCreatesNode() {
    let node = _resolve(Image(systemName: "star.fill"))
    if case .image(let name, _, _, _) = node {
        #expect(name == "star.fill")
    } else {
        Issue.record("Expected image node")
    }
}

@Test @MainActor func toggleCreatesNode() {
    let binding = Binding(get: { true }, set: { _ in })
    let node = _resolve(Toggle("Wi-Fi", isOn: binding))
    if case .toggle(let isOn, let label) = node {
        #expect(isOn == true)
        if case .text(let content, _, _, _) = label {
            #expect(content == "Wi-Fi")
        } else {
            Issue.record("Expected text label in Toggle")
        }
    } else {
        Issue.record("Expected toggle node")
    }
}

@Test @MainActor func textFieldCreatesNode() {
    let binding = Binding(get: { "" }, set: { _ in })
    let node = _resolve(TextField("Search...", text: binding))
    if case .textField(let placeholder, let text, _) = node {
        #expect(placeholder == "Search...")
        #expect(text == "")
    } else {
        Issue.record("Expected textField node")
    }
}

@Test @MainActor func navigationStackCreatesNode() {
    let node = _resolve(NavigationStack {
        Text("Content")
    })
    if case .navigationStack(let children) = node {
        #expect(children.count == 1)
    } else {
        Issue.record("Expected navigationStack node")
    }
}

@Test @MainActor func viewProtocolConformance() {
    // Text conforms to View, body returns ViewNode
    let text = Text("hello")
    let body: ViewNode = _resolve(text)
    #expect(body == .text("hello", fontSize: 14, color: .primary))
}

@Test @MainActor func observableObjectProtocol() {
    final class TestModel: ObservableObject {
        @Published var count = 0
    }
    let model = TestModel()
    #expect(model.count == 0)
    model.count = 5
    #expect(model.count == 5)
}

@Test @MainActor func environmentKey() {
    var env = EnvironmentValues()
    struct TestKey: EnvironmentKey {
        static let defaultValue = 42
    }
    #expect(env[TestKey.self] == 42)
    env[TestKey.self] = 100
    #expect(env[TestKey.self] == 100)
}

@Test @MainActor func shapeCircle() {
    let node = _resolve(Circle())
    if case .roundedRect(_, _, let radius, _) = node {
        #expect(radius == 1000)
    } else {
        Issue.record("Expected roundedRect from Circle()")
    }
}

@Test @MainActor func shapeCapsule() {
    let capsule = Capsule()
    let node = _resolve(capsule)
    if case .roundedRect(_, _, let radius, _) = node {
        #expect(radius == 1000)
    } else {
        Issue.record("Expected roundedRect from Capsule()")
    }
}

@Test @MainActor func buttonLayoutsCorrectly() {
    TapRegistry.shared.clear()
    let node = _resolve(Button("Tap me") {})
    let result = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 400, height: 300))
    #expect(result.frame.width == 400)
}

@Test @MainActor func scrollViewLayoutsLikeVStack() {
    let node = _resolve(ScrollView {
        ViewNode.rect(width: 100, height: 50, fill: .white)
        ViewNode.rect(width: 100, height: 50, fill: .white)
    })
    let result = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 400, height: 600))
    #expect(result.children.count >= 1) // TupleView wraps multiple children
}

@Test @MainActor func imageRendersAsPlaceholder() {
    let node = _resolve(Image("photo").frame(width: 100, height: 100))
    let layoutResult = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 400, height: 300))
    let commands = CommandFlattener.flatten(layoutResult)
    #expect(!commands.isEmpty)
}

@Test @MainActor func toggleRendersTrackAndKnob() {
    TapRegistry.shared.clear()
    let binding = Binding(get: { true }, set: { _ in })
    let node = _resolve(Toggle("Test", isOn: binding))
    let layoutResult = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 400, height: 40))
    let commands = CommandFlattener.flatten(layoutResult)
    // Should have at least track + knob
    #expect(commands.count >= 2)
}

@Test @MainActor func alignmentTypealiases() {
    let h: HorizontalAlignment = .center
    let v: VerticalAlignment = .center
    #expect(h == HAlignment.center)
    #expect(v == VAlignment.center)
}
