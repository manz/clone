import DesktopKit

print("Clone Desktop — Phase 3")

let desktop = Desktop(screenWidth: 1280, screenHeight: 800, mouseX: 640, mouseY: 750)
let tree = desktop.body()

// Layout and flatten to render commands
let layoutResult = Layout.layout(tree, in: LayoutFrame(x: 0, y: 0, width: 1280, height: 800))
let commands = CommandFlattener.flatten(layoutResult)
print("Generated \(commands.count) render commands")
for cmd in commands.prefix(10) {
    print("  [\(cmd.x), \(cmd.y)] \(cmd.width)x\(cmd.height) — \(cmd.kind)")
}
