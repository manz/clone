import Testing
@testable import SwiftUI

// MARK: - Smoke tests for new SwiftUI constructs

@Test func importSwiftUIAndCreateText() {
    let node = _resolve(Text("hello"))
    if case .text(let content, _, _, _) = node {
        #expect(content == "hello")
    } else {
        Issue.record("Expected text node")
    }
}

@Test func colorAsView() {
    let body = Color.blue.body
    if case .rect(let w, let h, let fill) = body {
        #expect(w == nil)
        #expect(h == nil)
        #expect(fill == .blue)
    } else {
        Issue.record("Expected rect from Color.body")
    }
}

@Test func buttonWithStringLabel() {
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

@Test func buttonWithCustomLabel() {
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

@Test func scrollViewCreatesNode() {
    let node = _resolve(ScrollView {
        Text("Item 1")
        Text("Item 2")
    })
    if case .scrollView(let axis, let children) = node {
        #expect(axis == .vertical)
        #expect(children.count == 2)
    } else {
        Issue.record("Expected scrollView node")
    }
}

@Test func listCreatesNode() {
    let node = _resolve(List {
        Text("Row 1")
        Text("Row 2")
    })
    if case .list(let children) = node {
        #expect(children.count == 2)
    } else {
        Issue.record("Expected list node")
    }
}

@Test func imageCreatesNode() {
    let node = _resolve(Image(systemName: "star.fill"))
    if case .image(let name, _, _) = node {
        #expect(name == "star.fill")
    } else {
        Issue.record("Expected image node")
    }
}

@Test func toggleCreatesNode() {
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

@Test func textFieldCreatesNode() {
    let binding = Binding(get: { "" }, set: { _ in })
    let node = _resolve(TextField("Search...", text: binding))
    if case .textField(let placeholder, let text) = node {
        #expect(placeholder == "Search...")
        #expect(text == "")
    } else {
        Issue.record("Expected textField node")
    }
}

@Test func navigationStackCreatesNode() {
    let node = _resolve(NavigationStack {
        Text("Content")
    })
    if case .navigationStack(let children) = node {
        #expect(children.count == 1)
    } else {
        Issue.record("Expected navigationStack node")
    }
}

@Test func viewProtocolConformance() {
    // Text conforms to View, body returns ViewNode
    let text = Text("hello")
    let body: ViewNode = text.body
    #expect(body == .text("hello", fontSize: 14, color: .primary))
}

@Test func observableObjectProtocol() {
    final class TestModel: ObservableObject {
        @Published var count = 0
    }
    let model = TestModel()
    #expect(model.count == 0)
    model.count = 5
    #expect(model.count == 5)
}

@Test func environmentKey() {
    var env = EnvironmentValues()
    struct TestKey: EnvironmentKey {
        static let defaultValue = 42
    }
    #expect(env[TestKey.self] == 42)
    env[TestKey.self] = 100
    #expect(env[TestKey.self] == 100)
}

@Test func shapeCircle() {
    let node = Circle()
    if case .roundedRect(_, _, let radius, _) = node {
        #expect(radius == 1000)
    } else {
        Issue.record("Expected roundedRect from Circle()")
    }
}

@Test func shapeCapsule() {
    let node = Capsule()
    if case .roundedRect(_, _, let radius, _) = node {
        #expect(radius == 1000)
    } else {
        Issue.record("Expected roundedRect from Capsule()")
    }
}

@Test func buttonLayoutsCorrectly() {
    TapRegistry.shared.clear()
    let node = _resolve(Button("Tap me") {})
    let result = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 400, height: 300))
    #expect(result.frame.width == 400)
}

@Test func scrollViewLayoutsLikeVStack() {
    let node = _resolve(ScrollView {
        ViewNode.rect(width: 100, height: 50, fill: .white)
        ViewNode.rect(width: 100, height: 50, fill: .white)
    })
    let result = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 400, height: 600))
    #expect(result.children.count == 2)
}

@Test func imageRendersAsPlaceholder() {
    let node = Image("photo").frame(width: 100, height: 100)
    let layoutResult = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 400, height: 300))
    let commands = CommandFlattener.flatten(layoutResult)
    #expect(!commands.isEmpty)
}

@Test func toggleRendersTrackAndKnob() {
    TapRegistry.shared.clear()
    let binding = Binding(get: { true }, set: { _ in })
    let node = _resolve(Toggle("Test", isOn: binding))
    let layoutResult = Layout.layout(node, in: LayoutFrame(x: 0, y: 0, width: 400, height: 40))
    let commands = CommandFlattener.flatten(layoutResult)
    // Should have at least track + knob
    #expect(commands.count >= 2)
}

@Test func alignmentTypealiases() {
    let h: HorizontalAlignment = .center
    let v: VerticalAlignment = .center
    #expect(h == HAlignment.center)
    #expect(v == VAlignment.center)
}
