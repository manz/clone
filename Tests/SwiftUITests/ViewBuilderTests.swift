import Testing
@testable import SwiftUI

@Test func emptyViewNode() {
    let node = ViewNode.empty
    #expect(node == .empty)
}

@Test func textNode() {
    let node = ViewNode.text("Hello", fontSize: 16, color: .white)
    #expect(node == .text("Hello", fontSize: 16, color: .white))
}

@Test func textNodeInequality() {
    let a = ViewNode.text("A", fontSize: 16, color: .white)
    let b = ViewNode.text("B", fontSize: 16, color: .white)
    #expect(a != b)
}

@Test func rectNode() {
    let node = ViewNode.rect(width: 100, height: 50, fill: .systemBlue)
    #expect(node == .rect(width: 100, height: 50, fill: .systemBlue))
}

@Test func roundedRectNode() {
    let node = ViewNode.roundedRect(width: 200, height: 100, radius: 12, fill: .surface)
    #expect(node == .roundedRect(width: 200, height: 100, radius: 12, fill: .surface))
}

@Test func vstackBuilder() {
    let node = ViewNode.vstack(spacing: 10) {
        ViewNode.text("Top", fontSize: 14, color: .text)
        ViewNode.text("Bottom", fontSize: 14, color: .text)
    }
    if case .vstack(let alignment, let spacing, let children) = node {
        #expect(alignment == .center)
        #expect(spacing == 10)
        #expect(children.count == 2)
    } else {
        Issue.record("Expected vstack")
    }
}

@Test func hstackBuilder() {
    let node = ViewNode.hstack(alignment: .top, spacing: 4) {
        ViewNode.spacer(minLength: 0)
        ViewNode.text("Label", fontSize: 12, color: .subtle)
    }
    if case .hstack(let alignment, let spacing, let children) = node {
        #expect(alignment == .top)
        #expect(spacing == 4)
        #expect(children.count == 2)
    } else {
        Issue.record("Expected hstack")
    }
}

@Test func zstackBuilder() {
    let node = ViewNode.zstack {
        ViewNode.rect(width: nil, height: nil, fill: .base)
        ViewNode.text("Overlay", fontSize: 24, color: .white)
    }
    if case .zstack(let children) = node {
        #expect(children.count == 2)
    } else {
        Issue.record("Expected zstack")
    }
}

@Test func paddingNode() {
    let inner = ViewNode.text("Padded", fontSize: 14, color: .text)
    let node = ViewNode.padding(EdgeInsets(all: 16), child: inner)
    if case .padding(let insets, let child) = node {
        #expect(insets.top == 16)
        #expect(insets.leading == 16)
        #expect(child == inner)
    } else {
        Issue.record("Expected padding")
    }
}

@Test func frameNode() {
    let inner = ViewNode.text("Framed", fontSize: 14, color: .text)
    let node = ViewNode.frame(width: 300, height: nil, child: inner)
    if case .frame(let w, let h, let child) = node {
        #expect(w == 300)
        #expect(h == nil)
        #expect(child == inner)
    } else {
        Issue.record("Expected frame")
    }
}

@Test func opacityNode() {
    let inner = ViewNode.rect(width: 50, height: 50, fill: .white)
    let node = ViewNode.opacity(0.5, child: inner)
    if case .opacity(let val, let child) = node {
        #expect(val == 0.5)
        #expect(child == inner)
    } else {
        Issue.record("Expected opacity")
    }
}

@Test func onTapNode() {
    let inner = ViewNode.text("Tap me", fontSize: 16, color: .systemBlue)
    let node = ViewNode.onTap(id: 42, child: inner)
    if case .onTap(let id, let child) = node {
        #expect(id == 42)
        #expect(child == inner)
    } else {
        Issue.record("Expected onTap")
    }
}

@Test func nestedTree() {
    let tree = ViewNode.vstack {
        ViewNode.hstack {
            ViewNode.text("Left", fontSize: 14, color: .text)
            ViewNode.spacer(minLength: 0)
            ViewNode.text("Right", fontSize: 14, color: .text)
        }
        ViewNode.roundedRect(width: nil, height: 200, radius: 12, fill: .surface)
    }
    if case .vstack(_, _, let children) = tree {
        #expect(children.count == 2)
        if case .hstack(_, _, let inner) = children[0] {
            #expect(inner.count == 3)
        } else {
            Issue.record("Expected inner hstack")
        }
    } else {
        Issue.record("Expected vstack")
    }
}

@Test func colorEquality() {
    #expect(Color.white == Color(r: 1, g: 1, b: 1, a: 1))
    #expect(Color.black != Color.white)
}

@Test func edgeInsetsConvenience() {
    let uniform = EdgeInsets(all: 8)
    #expect(uniform.top == 8)
    #expect(uniform.leading == 8)
    #expect(uniform.bottom == 8)
    #expect(uniform.trailing == 8)

    let hv = EdgeInsets(horizontal: 16, vertical: 8)
    #expect(hv.top == 8)
    #expect(hv.leading == 16)
}
