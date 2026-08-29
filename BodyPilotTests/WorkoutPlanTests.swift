import Foundation
import Testing
@testable import BodyPilot

struct WorkoutPlanTests {
    /// 5-minute warm-up, 20-minute main, 5-minute cool-down.
    private var plan: PlannedWorkout {
        PlannedWorkout(
            title: "Test",
            activity: .walking,
            intensity: .moderate,
            steps: [
                WorkoutStep(phase: .warmup, name: "W", detail: "", durationMinutes: 5, intensity: .light),
                WorkoutStep(phase: .main, name: "M", detail: "", durationMinutes: 20, intensity: .moderate),
                WorkoutStep(phase: .cooldown, name: "C", detail: "", durationMinutes: 5, intensity: .light),
            ],
            explanation: ""
        )
    }

    @Test("Step index follows elapsed time across boundaries")
    func stepIndexProgression() {
        #expect(plan.stepIndex(atMinutes: 0) == 0)
        #expect(plan.stepIndex(atMinutes: 4.9) == 0)
        #expect(plan.stepIndex(atMinutes: 5) == 1)
        #expect(plan.stepIndex(atMinutes: 24.9) == 1)
        #expect(plan.stepIndex(atMinutes: 25) == 2)
        #expect(plan.stepIndex(atMinutes: 29.9) == 2)
    }

    @Test("Step index is nil after the plan is finished")
    func stepIndexAfterEnd() {
        #expect(plan.stepIndex(atMinutes: 30) == nil)
        #expect(plan.stepIndex(atMinutes: 100) == nil)
    }

    @Test("Remaining minutes count down within the current step")
    func remainingMinutes() throws {
        let remaining = try #require(plan.remainingMinutes(atMinutes: 27))
        #expect(abs(remaining - 3) < 0.000_1)
        #expect(plan.remainingMinutes(atMinutes: 31) == nil)
    }

    @Test("Total minutes is the sum of all steps")
    func totalMinutes() {
        #expect(plan.totalMinutes == 30)
    }
}
