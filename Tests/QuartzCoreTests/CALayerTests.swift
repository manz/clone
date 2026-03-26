import Testing
import CoreGraphics
@testable import QuartzCore

@Suite("CALayer")
struct CALayerTests {

    @Test func defaultProperties() {
        let layer = CALayer()
        #expect(layer.bounds == .zero)
        #expect(layer.position == .zero)
        #expect(layer.anchorPoint == CGPoint(x: 0.5, y: 0.5))
        #expect(layer.opacity == 1.0)
        #expect(layer.isHidden == false)
        #expect(layer.cornerRadius == 0)
        #expect(layer.masksToBounds == false)
        #expect(layer.contentsScale == 1.0)
        #expect(layer.zPosition == 0)
        #expect(layer.sublayers == nil)
        #expect(layer.superlayer == nil)
        #expect(layer.shadowOpacity == 0)
        #expect(layer.shadowRadius == 3)
        #expect(layer.shadowOffset == CGSize(width: 0, height: -3))
        #expect(layer.needsDisplay == true)
    }

    @Test func frameComputedFromBoundsPositionAnchor() {
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: 100, height: 80)
        layer.position = CGPoint(x: 200, y: 150)
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        let frame = layer.frame
        #expect(frame.origin.x == 150)
        #expect(frame.origin.y == 110)
        #expect(frame.width == 100)
        #expect(frame.height == 80)
    }

    @Test func setFrameUpdatesBoundsAndPosition() {
        let layer = CALayer()
        layer.frame = CGRect(x: 50, y: 30, width: 200, height: 100)

        #expect(layer.bounds.size == CGSize(width: 200, height: 100))
        #expect(layer.position == CGPoint(x: 150, y: 80))
    }

    @Test func frameWithTopLeftAnchor() {
        let layer = CALayer()
        layer.anchorPoint = CGPoint(x: 0, y: 0)
        layer.bounds = CGRect(x: 0, y: 0, width: 100, height: 50)
        layer.position = CGPoint(x: 10, y: 20)

        #expect(layer.frame == CGRect(x: 10, y: 20, width: 100, height: 50))
    }

    @Test func addSublayer() {
        let parent = CALayer()
        let child = CALayer()

        parent.addSublayer(child)

        #expect(parent.sublayers?.count == 1)
        #expect(parent.sublayers?.first === child)
        #expect(child.superlayer === parent)
    }

    @Test func removeFromSuperlayer() {
        let parent = CALayer()
        let child = CALayer()
        parent.addSublayer(child)

        child.removeFromSuperlayer()

        #expect(parent.sublayers == nil)
        #expect(child.superlayer == nil)
    }

    @Test func addSublayerRemovesFromPreviousParent() {
        let parent1 = CALayer()
        let parent2 = CALayer()
        let child = CALayer()

        parent1.addSublayer(child)
        parent2.addSublayer(child)

        #expect(parent1.sublayers == nil)
        #expect(parent2.sublayers?.count == 1)
        #expect(child.superlayer === parent2)
    }

    @Test func insertSublayerAtIndex() {
        let parent = CALayer()
        let a = CALayer(); a.name = "a"
        let b = CALayer(); b.name = "b"
        let c = CALayer(); c.name = "c"

        parent.addSublayer(a)
        parent.addSublayer(c)
        parent.insertSublayer(b, at: 1)

        #expect(parent.sublayers?.map(\.name) == ["a", "b", "c"])
    }

    @Test func insertSublayerBelowSibling() {
        let parent = CALayer()
        let a = CALayer(); a.name = "a"
        let b = CALayer(); b.name = "b"
        let c = CALayer(); c.name = "c"

        parent.addSublayer(a)
        parent.addSublayer(c)
        parent.insertSublayer(b, below: c)

        #expect(parent.sublayers?.map(\.name) == ["a", "b", "c"])
    }

    @Test func insertSublayerAboveSibling() {
        let parent = CALayer()
        let a = CALayer(); a.name = "a"
        let b = CALayer(); b.name = "b"
        let c = CALayer(); c.name = "c"

        parent.addSublayer(a)
        parent.addSublayer(c)
        parent.insertSublayer(b, above: a)

        #expect(parent.sublayers?.map(\.name) == ["a", "b", "c"])
    }

    @Test func replaceSublayer() {
        let parent = CALayer()
        let old = CALayer(); old.name = "old"
        let new = CALayer(); new.name = "new"

        parent.addSublayer(old)
        parent.replaceSublayer(old, with: new)

        #expect(parent.sublayers?.count == 1)
        #expect(parent.sublayers?.first?.name == "new")
        #expect(old.superlayer == nil)
        #expect(new.superlayer === parent)
    }

    @Test func setNeedsDisplayAndDisplayIfNeeded() {
        let layer = CALayer()
        // freshly created layer needs display
        #expect(layer.needsDisplay == true)

        layer.displayIfNeeded()
        #expect(layer.needsDisplay == false)

        layer.setNeedsDisplay()
        #expect(layer.needsDisplay == true)
    }

    @Test func hitTestReturnsDeepestLayer() {
        let parent = CALayer()
        parent.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        parent.bounds = CGRect(x: 0, y: 0, width: 200, height: 200)

        let child = CALayer()
        child.frame = CGRect(x: 50, y: 50, width: 100, height: 100)
        child.bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        parent.addSublayer(child)

        let hit = parent.hitTest(CGPoint(x: 75, y: 75))
        #expect(hit === child)
    }

    @Test func hitTestReturnsNilForHiddenLayer() {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        layer.bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        layer.isHidden = true

        #expect(layer.hitTest(CGPoint(x: 50, y: 50)) == nil)
    }

    @Test func hitTestMissesOutsideBounds() {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        layer.bounds = CGRect(x: 0, y: 0, width: 100, height: 100)

        #expect(layer.hitTest(CGPoint(x: 150, y: 150)) == nil)
    }

    @Test func copyInit() {
        let original = CALayer()
        original.bounds = CGRect(x: 0, y: 0, width: 100, height: 50)
        original.position = CGPoint(x: 75, y: 25)
        original.opacity = 0.5
        original.cornerRadius = 8
        original.name = "test"

        let copy = CALayer(layer: original)
        #expect(copy.bounds == original.bounds)
        #expect(copy.position == original.position)
        #expect(copy.opacity == original.opacity)
        #expect(copy.cornerRadius == original.cornerRadius)
        #expect(copy.name == original.name)
    }

    @Test func convertPointBetweenLayers() {
        let parent = CALayer()
        parent.frame = CGRect(x: 0, y: 0, width: 300, height: 300)

        let a = CALayer()
        a.frame = CGRect(x: 10, y: 20, width: 100, height: 100)
        parent.addSublayer(a)

        let b = CALayer()
        b.frame = CGRect(x: 50, y: 60, width: 100, height: 100)
        parent.addSublayer(b)

        // Point (0,0) in a's coordinate space → b's coordinate space
        let converted = b.convert(CGPoint(x: 0, y: 0), from: a)
        #expect(converted.x == -40) // 0 + 10 - 50
        #expect(converted.y == -40) // 0 + 20 - 60
    }
}

@Suite("CALayer subclasses")
struct CALayerSubclassTests {

    @Test func shapeLayerDefaults() {
        let layer = CAShapeLayer()
        #expect(layer.path == nil)
        #expect(layer.fillColor == nil)
        #expect(layer.strokeColor == nil)
        #expect(layer.lineWidth == 1)
        #expect(layer.strokeStart == 0)
        #expect(layer.strokeEnd == 1)
        #expect(layer.fillRule == .nonZero)
    }

    @Test func textLayerDefaults() {
        let layer = CATextLayer()
        #expect(layer.fontSize == 36)
        #expect(layer.isWrapped == false)
        #expect(layer.truncationMode == .none)
        #expect(layer.alignmentMode == .natural)
    }

    @Test func gradientLayerDefaults() {
        let layer = CAGradientLayer()
        #expect(layer.colors == nil)
        #expect(layer.locations == nil)
        #expect(layer.startPoint == CGPoint(x: 0.5, y: 0))
        #expect(layer.endPoint == CGPoint(x: 0.5, y: 1))
        #expect(layer.type == .axial)
    }

    @Test func scrollLayerScrollToPoint() {
        let layer = CAScrollLayer()
        layer.scroll(to: CGPoint(x: 10, y: 20))
        #expect(layer.bounds.origin == CGPoint(x: 10, y: 20))
    }

    @Test func shapeLayerInheritsFromCALayer() {
        let layer = CAShapeLayer()
        layer.opacity = 0.5
        layer.cornerRadius = 4
        #expect(layer.opacity == 0.5)
        #expect(layer.cornerRadius == 4)
    }
}
