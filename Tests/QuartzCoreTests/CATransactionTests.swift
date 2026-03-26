import Testing
@testable import QuartzCore

@Suite("CATransaction")
struct CATransactionTests {

    @Test func defaultDuration() {
        #expect(CATransaction.animationDuration() == 0.25)
    }

    @Test func disableActionsDefaultFalse() {
        #expect(CATransaction.disableActions() == false)
    }

    @Test func beginCommitCycle() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.5)
        #expect(CATransaction.animationDuration() == 0.5)
        CATransaction.commit()
        // After commit, back to default
        #expect(CATransaction.animationDuration() == 0.25)
    }

    @Test func nestedTransactions() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.5)

        CATransaction.begin()
        CATransaction.setAnimationDuration(1.0)
        #expect(CATransaction.animationDuration() == 1.0)
        CATransaction.commit()

        #expect(CATransaction.animationDuration() == 0.5)
        CATransaction.commit()
    }

    @Test func setDisableActions() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        #expect(CATransaction.disableActions() == true)
        CATransaction.commit()
    }

    @Test func completionBlockCalledOnCommit() {
        var called = false
        CATransaction.begin()
        CATransaction.setCompletionBlock { called = true }
        CATransaction.commit()
        #expect(called == true)
    }

    @Test func flushCommitsAllTransactions() {
        var count = 0
        CATransaction.begin()
        CATransaction.setCompletionBlock { count += 1 }
        CATransaction.begin()
        CATransaction.setCompletionBlock { count += 1 }
        CATransaction.flush()
        #expect(count == 2)
    }

    @Test func setValueForKey() {
        CATransaction.begin()
        CATransaction.setValue(0.75, forKey: "animationDuration")
        #expect(CATransaction.animationDuration() == 0.75)
        CATransaction.commit()
    }

    @Test func timingFunction() {
        CATransaction.begin()
        let fn = CAMediaTimingFunction(name: .easeIn)
        CATransaction.setAnimationTimingFunction(fn)
        #expect(CATransaction.animationTimingFunction() != nil)
        CATransaction.commit()
    }
}
