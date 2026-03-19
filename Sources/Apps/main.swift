import DesktopKit

/// Minimal desktop app — returns a single colored rect to prove the engine works.
struct DesktopApp {
    func body(width: Float, height: Float) -> ViewNode {
        .zstack {
            // Background
            ViewNode.rect(width: width, height: height, fill: .base)
            // Centered card
            ViewNode.vstack(spacing: 16) {
                ViewNode.roundedRect(width: 400, height: 300, radius: 16, fill: .surface)
                ViewNode.text("Clone Desktop", fontSize: 24, color: .text)
            }
        }
    }
}

print("Clone Desktop — Phase 1")
let app = DesktopApp()
let tree = app.body(width: 1280, height: 800)
print("View tree: \(tree)")
