import Testing
@testable import QuartzCore

@Suite("CAMediaTimingFunction")
struct CAMediaTimingFunctionTests {

    @Test func linearStartAndEnd() {
        let fn = CAMediaTimingFunction(name: .linear)
        #expect(fn.evaluate(at: 0) == 0)
        let endVal = fn.evaluate(at: 1)
        #expect(abs(endVal - 1.0) < 0.01)
    }

    @Test func linearMidpoint() {
        let fn = CAMediaTimingFunction(name: .linear)
        let mid = fn.evaluate(at: 0.5)
        #expect(abs(mid - 0.5) < 0.01)
    }

    @Test func easeInStartsSlow() {
        let fn = CAMediaTimingFunction(name: .easeIn)
        let earlyProgress = fn.evaluate(at: 0.2)
        // Ease-in should be below linear at the start
        #expect(earlyProgress < 0.2)
    }

    @Test func easeOutStartsFast() {
        let fn = CAMediaTimingFunction(name: .easeOut)
        let earlyProgress = fn.evaluate(at: 0.2)
        // Ease-out should be above linear at the start
        #expect(earlyProgress > 0.2)
    }

    @Test func easeInEaseOutSymmetric() {
        let fn = CAMediaTimingFunction(name: .easeInEaseOut)
        let mid = fn.evaluate(at: 0.5)
        #expect(abs(mid - 0.5) < 0.05)
    }

    @Test func customControlPoints() {
        let fn = CAMediaTimingFunction(controlPoints: 0.0, 0.0, 1.0, 1.0)
        let mid = fn.evaluate(at: 0.5)
        // Linear curve via control points
        #expect(abs(mid - 0.5) < 0.05)
    }

    @Test func getControlPointReturnsCorrectValues() {
        let fn = CAMediaTimingFunction(controlPoints: 0.42, 0.0, 0.58, 1.0)
        var values: [Float] = [0, 0]
        fn.getControlPoint(at: 0, values: &values)
        #expect(values == [0, 0]) // P0 is always (0,0)

        fn.getControlPoint(at: 1, values: &values)
        #expect(values[0] == 0.42)
        #expect(values[1] == 0.0)

        fn.getControlPoint(at: 2, values: &values)
        #expect(values[0] == 0.58)
        #expect(values[1] == 1.0)

        fn.getControlPoint(at: 3, values: &values)
        #expect(values == [1, 1]) // P3 is always (1,1)
    }

    @Test func fillModeConstants() {
        #expect(CAMediaTimingFillMode.removed.rawValue == "removed")
        #expect(CAMediaTimingFillMode.forwards.rawValue == "forwards")
        #expect(CAMediaTimingFillMode.backwards.rawValue == "backwards")
        #expect(CAMediaTimingFillMode.both.rawValue == "both")
    }
}
