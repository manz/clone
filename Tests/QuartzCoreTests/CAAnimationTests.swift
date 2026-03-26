import Testing
@testable import QuartzCore

@Suite("CAAnimation")
struct CAAnimationTests {

    @Test func basicAnimationDefaults() {
        let anim = CABasicAnimation(keyPath: "opacity")
        #expect(anim.keyPath == "opacity")
        #expect(anim.fromValue == nil)
        #expect(anim.toValue == nil)
        #expect(anim.duration == 0)
        #expect(anim.fillMode == .removed)
        #expect(anim.isRemovedOnCompletion == true)
    }

    @Test func keyframeAnimationProperties() {
        let anim = CAKeyframeAnimation(keyPath: "position")
        anim.values = [0, 50, 100]
        anim.keyTimes = [0, 0.5, 1.0]
        #expect(anim.values?.count == 3)
        #expect(anim.keyTimes?.count == 3)
        #expect(anim.calculationMode == .linear)
    }

    @Test func springAnimationSettlingDuration() {
        let spring = CASpringAnimation(keyPath: "bounds")
        spring.mass = 1
        spring.stiffness = 100
        spring.damping = 10

        // Settling duration should be positive for underdamped spring
        #expect(spring.settlingDuration > 0)
    }

    @Test func animationGroupHoldsMultiple() {
        let group = CAAnimationGroup()
        let a = CABasicAnimation(keyPath: "opacity")
        let b = CABasicAnimation(keyPath: "position")
        group.animations = [a, b]
        #expect(group.animations?.count == 2)
    }

    @Test func transitionDefaults() {
        let transition = CATransition()
        #expect(transition.type == .fade)
        #expect(transition.subtype == nil)
        #expect(transition.startProgress == 0)
        #expect(transition.endProgress == 1)
    }

    @Test func layerAnimationStubs() {
        let layer = CALayer()
        let anim = CABasicAnimation(keyPath: "opacity")

        // These are stubs — should not crash
        layer.add(anim, forKey: "fade")
        #expect(layer.animation(forKey: "fade") == nil) // stub returns nil
        #expect(layer.animationKeys() == nil)
        layer.removeAnimation(forKey: "fade")
        layer.removeAllAnimations()
    }
}

@Suite("CATransform3D")
struct CATransform3DTests {

    @Test func identityIsDefault() {
        let t = CATransform3D()
        #expect(CATransform3DIsIdentity(t) == true)
    }

    @Test func identityConstant() {
        #expect(CATransform3DIsIdentity(CATransform3DIdentity) == true)
    }

    @Test func equalToTransform() {
        let a = CATransform3D()
        let b = CATransform3D()
        #expect(CATransform3DEqualToTransform(a, b) == true)
    }

    @Test func nonIdentityIsNotIdentity() {
        var t = CATransform3D()
        t.m11 = 2
        #expect(CATransform3DIsIdentity(t) == false)
    }
}

@Suite("CACurrentMediaTime")
struct CACurrentMediaTimeTests {

    @Test func returnsPositiveValue() {
        let time = CACurrentMediaTime()
        #expect(time > 0)
    }

    @Test func isMonotonic() {
        let t1 = CACurrentMediaTime()
        let t2 = CACurrentMediaTime()
        #expect(t2 >= t1)
    }
}
