import Foundation
import Testing
@testable import BodyPilot

struct InsightEngineTests {
    /// Fixed UTC calendar so results don't depend on the machine's time zone.
    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    private let engine = InsightEngine(
        baselineEngine: BaselineEngine(calendar: utcCalendar),
        actionEngine: InsightActionEngine(),
        calendar: utcCalendar
    )
    /// 2026-01-31 00:00 UTC — "today" for these tests.
    private let today = Date(timeIntervalSince1970: 1_769_817_600)

    private func day(_ offset: Int) -> Date {
        today.addingTimeInterval(Double(offset) * 86_400)
    }

    private func snapshot(offset: Int, sleep: Double? = nil, hrv: Double? = nil, steps: Double? = nil) -> DailyHealthSnapshot {
        DailyHealthSnapshot(
            date: day(offset),
            sleepHours: sleep,
            hrvSDNN: hrv,
            restingHeartRate: nil,
            steps: steps,
            activeEnergyKilocalories: nil,
            exerciseMinutes: nil
        )
    }

    private func score(_ readiness: ReadinessLevel, confidence: Double = 0.8) -> BodyScoreResult {
        BodyScoreResult(
            score: readiness == .strong ? 85 : readiness == .ready ? 70 : readiness == .easy ? 55 : 30,
            confidence: confidence,
            readiness: readiness,
            components: [],
            explanationFacts: [ExplanationFact(title: "Sleep", detail: "Close to normal.")],
            computedAt: today
        )
    }

    private func input(
        snapshots: [DailyHealthSnapshot] = [],
        workouts: [WorkoutSummary] = [],
        score: BodyScoreResult? = nil,
        recentLoad: TrainingLoad? = nil,
        feeling: FeelingLevel? = nil
    ) -> InsightInput {
        InsightInput(
            snapshots: snapshots,
            workouts: workouts,
            score: score,
            deltas: nil,
            recentLoad: recentLoad,
            feeling: feeling,
            date: today
        )
    }

    // MARK: - General shape

    @Test("V1 produces the five insight worlds in hub order")
    func producesFiveWorlds() {
        let insights = engine.insights(for: input())
        #expect(insights.map(\.kind) == [.sleep, .movement, .recovery, .trainingLoad, .workoutHistory])
    }

    @Test("Empty input yields unknown statuses, never invented values")
    func emptyInputIsUnknown() {
        let insights = engine.insights(for: input())
        let sleep = insights[0]
        let movement = insights[1]
        let recovery = insights[2]
        #expect(sleep.status == .unknown)
        #expect(sleep.confidence == 0)
        #expect(sleep.primaryValueText == "—")
        #expect(movement.status == .unknown)
        #expect(recovery.status == .unknown)
    }

    // MARK: - Sleep

    @Test("Sleep clearly above the personal baseline is excellent")
    func sleepAboveBaseline() {
        var days = (1...20).map { snapshot(offset: -$0, sleep: 7.0) }
        days.append(snapshot(offset: 0, sleep: 7.7))
        let sleep = engine.insights(for: input(snapshots: days))[0]
        #expect(sleep.status == .excellent)
        #expect(sleep.confidence == 1)
        #expect(!sleep.facts.isEmpty)
        #expect(!sleep.comparisons.isEmpty)
    }

    @Test("Sleep well below the personal baseline is low and suggests an easier session")
    func sleepBelowBaseline() {
        var days = (1...20).map { snapshot(offset: -$0, sleep: 7.5) }
        days.append(snapshot(offset: 0, sleep: 5.5))
        let sleep = engine.insights(for: input(snapshots: days, score: score(.easy)))[0]
        #expect(sleep.status == .low)
        #expect(sleep.action?.activity == .recovery)
    }

    // MARK: - Movement

    @Test("Steps below baseline produce a gap-sized walk capped at 20 minutes")
    func movementBelowBaseline() {
        var days = (1...20).map { snapshot(offset: -$0, steps: 8000) }
        days.append(snapshot(offset: 0, steps: 4000))
        let movement = engine.insights(for: input(snapshots: days))[1]
        #expect(movement.status == .steady)
        let action = movement.action
        #expect(action?.activity == .walking)
        #expect(action?.timeLimitMinutes == 20)
    }

    @Test("Steps at or above baseline are excellent")
    func movementAheadOfBaseline() {
        var days = (1...20).map { snapshot(offset: -$0, steps: 6000) }
        days.append(snapshot(offset: 0, steps: 6500))
        let movement = engine.insights(for: input(snapshots: days))[1]
        #expect(movement.status == .excellent)
    }

    // MARK: - Recovery

    @Test("Recovery status mirrors the readiness band")
    func recoveryMapsReadiness() {
        #expect(engine.insights(for: input(score: score(.strong)))[2].status == .excellent)
        #expect(engine.insights(for: input(score: score(.ready)))[2].status == .good)
        #expect(engine.insights(for: input(score: score(.easy)))[2].status == .steady)
        #expect(engine.insights(for: input(score: score(.recover)))[2].status == .low)
    }

    @Test("Recovery confidence comes from the Body Score, and check-ins become facts")
    func recoveryConfidenceAndFeeling() {
        let recovery = engine.insights(for: input(score: score(.ready, confidence: 0.6), feeling: .tired))[2]
        #expect(recovery.confidence == 0.6)
        #expect(recovery.facts.contains { $0.detail.contains("tired") || $0.title.contains("check-in") })
    }

    @Test("A recover day suggests a recovery session, never a workout")
    func recoverDayAction() {
        let recovery = engine.insights(for: input(score: score(.recover)))[2]
        #expect(recovery.action?.activity == .recovery)
        #expect(recovery.action?.timeLimitMinutes == 20)
    }

    // MARK: - Training load

    @Test("Weekly minutes and heavy-load status derive from workout history")
    func trainingLoadWeek() {
        let workouts = [
            WorkoutSummary(start: day(-1), durationMinutes: 150, activity: .walking, totalEnergyKilocalories: nil),
            WorkoutSummary(start: day(-3), durationMinutes: 150, activity: .strength, totalEnergyKilocalories: nil),
            WorkoutSummary(start: day(-20), durationMinutes: 100, activity: .walking, totalEnergyKilocalories: nil),
        ]
        let load = engine.insights(for: input(workouts: workouts, recentLoad: .heavy))[3]
        #expect(load.status == .low)
        #expect(load.primaryValueText.contains("300"))
        #expect(load.trend == .up)
        #expect(load.pattern.count == 7)
    }

    @Test("No recent load reads as rested, not as a failure")
    func trainingLoadRest() {
        let load = engine.insights(for: input(recentLoad: .rest))[3]
        #expect(load.status == .steady)
    }

    // MARK: - Workout journey

    @Test("Journey counts the last 30 days of workouts")
    func journeyCounts() {
        let workouts = [
            WorkoutSummary(start: day(-2), durationMinutes: 30, activity: .walking, totalEnergyKilocalories: nil),
            WorkoutSummary(start: day(-10), durationMinutes: 25, activity: .strength, totalEnergyKilocalories: nil),
            WorkoutSummary(start: day(-40), durationMinutes: 60, activity: .walking, totalEnergyKilocalories: nil),
        ]
        let journey = engine.insights(for: input(workouts: workouts))[4]
        #expect(journey.status == .steady)
        #expect(journey.primaryValueText.contains("2"))
        #expect(journey.confidence == 1)
    }

    // MARK: - Action engine

    @Test("Movement gap sizes the walk inside 10–20 minutes")
    func actionWalkSizing() {
        let actions = InsightActionEngine()
        #expect(actions.action(for: .movement, readiness: .ready, movementGapSteps: 1400)?.timeLimitMinutes == 14)
        #expect(actions.action(for: .movement, readiness: .ready, movementGapSteps: 300)?.timeLimitMinutes == 10)
        #expect(actions.action(for: .movement, readiness: .ready, movementGapSteps: 9000)?.timeLimitMinutes == 20)
    }

    @Test("V1.1 worlds have no CTA yet")
    func futureWorldsHaveNoAction() {
        let actions = InsightActionEngine()
        #expect(actions.action(for: .heart, readiness: .ready) == nil)
        #expect(actions.action(for: .strength, readiness: .ready) == nil)
        #expect(actions.action(for: .mobilityBalance, readiness: .ready) == nil)
    }

    // MARK: - Explainer prompt

    @Test("The explainer prompt carries only validated facts and pins the action")
    func explainerPromptContent() {
        var days = (1...20).map { snapshot(offset: -$0, sleep: 7.0) }
        days.append(snapshot(offset: 0, sleep: 7.7))
        let sleep = engine.insights(for: input(snapshots: days, score: score(.ready)))[0]
        let context = InsightContextBuilder().context(for: sleep)
        let prompt = InsightExplainerPrompt.prompt(for: context)

        #expect(prompt.contains("Insight: sleep"))
        for fact in sleep.facts {
            #expect(prompt.contains(fact.detail))
        }
        if let action = sleep.action {
            #expect(prompt.contains(action.title))
            #expect(prompt.contains("do not change it"))
        }
    }

    @Test("Explainer instructions forbid invention and diagnosis")
    func explainerInstructionsGuardrails() {
        let instructions = InsightExplainerPrompt.instructions
        #expect(instructions.contains("never invent"))
        #expect(instructions.contains("Never diagnose"))
        #expect(instructions.contains("Do not contradict"))
    }

    // MARK: - Context builder

    @Test("InsightContext carries only the snapshot's validated facts")
    func contextPassthrough() {
        var days = (1...20).map { snapshot(offset: -$0, sleep: 7.0) }
        days.append(snapshot(offset: 0, sleep: 7.7))
        let sleep = engine.insights(for: input(snapshots: days, score: score(.ready)))[0]
        let context = InsightContextBuilder().context(for: sleep)
        #expect(context.kind == .sleep)
        #expect(context.status == sleep.status)
        #expect(context.facts == sleep.facts)
        #expect(context.baselineComparisons == sleep.comparisons)
        #expect(context.safeActions == [sleep.action?.title].compactMap(\.self))
        #expect(context.confidence == sleep.confidence)
    }
}
