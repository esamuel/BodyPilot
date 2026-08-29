import Foundation
import Testing
@testable import BodyPilot

struct BodyScoreEngineTests {
    private let engine = BodyScoreEngine()
    private let now = Date(timeIntervalSince1970: 1_769_817_600)

    private func input(
        sleepDelta: Double? = nil,
        hrvDelta: Double? = nil,
        restingHRDeltaBPM: Double? = nil,
        recentLoad: TrainingLoad? = nil,
        recoveryConsistency: Double? = nil,
        feeling: FeelingLevel? = nil
    ) -> BodyScoreInput {
        BodyScoreInput(
            deltas: BaselineDeltas(sleepDelta: sleepDelta, hrvDelta: hrvDelta, restingHRDeltaBPM: restingHRDeltaBPM),
            recentLoad: recentLoad,
            recoveryConsistency: recoveryConsistency,
            feeling: feeling,
            date: now
        )
    }

    @Test("All signals normal produces a high score with full confidence")
    func allSignalsNormal() {
        let result = engine.computeScore(
            from: input(
                sleepDelta: 0, hrvDelta: 0, restingHRDeltaBPM: 0,
                recentLoad: .moderate, recoveryConsistency: 1.0, feeling: .normal
            )
        )
        // 0.25 + 0.20 + 0.15 + 0.75×0.20 + 0.10 + 0.7×0.10 = 0.92
        #expect(result.score == 92)
        #expect(result.confidence == 1.0)
        #expect(result.readiness == .strong)
        #expect(result.components.count == 6)
    }

    @Test("No data at all yields a neutral score with zero confidence")
    func noData() {
        let result = engine.computeScore(from: input())
        #expect(result.score == 50)
        #expect(result.confidence == 0)
        #expect(result.readiness == .easy)
        #expect(result.components.allSatisfy { $0.normalizedValue == nil })
    }

    @Test("Missing sleep reduces confidence and renormalizes remaining weights")
    func missingSleep() {
        let result = engine.computeScore(
            from: input(
                hrvDelta: 0, restingHRDeltaBPM: 0,
                recentLoad: .moderate, recoveryConsistency: 1.0, feeling: .normal
            )
        )
        // Available weight 0.75; weighted sum 0.67 → 0.67 / 0.75 ≈ 89
        #expect(result.score == 89)
        #expect(abs(result.confidence - 0.75) < 0.000_1)
    }

    @Test("Uniformly poor signals land in the Recover band")
    func poorSignals() {
        let result = engine.computeScore(
            from: input(
                sleepDelta: -0.4, hrvDelta: -0.3, restingHRDeltaBPM: 8,
                recentLoad: .heavy, recoveryConsistency: 0.2, feeling: .veryTired
            )
        )
        // 0.2×0.25 + 0.4×0.20 + 0.2×0.15 + 0.5×0.20 + 0.2×0.10 + 0 = 0.28
        #expect(result.score == 28)
        #expect(result.readiness == .recover)
    }

    @Test("Extreme deltas are clamped and the score stays in 0…100")
    func extremeValuesClamped() {
        let high = engine.computeScore(
            from: input(sleepDelta: 5.0, hrvDelta: 9.0, restingHRDeltaBPM: -50, recentLoad: .rest, recoveryConsistency: 1.0, feeling: .excellent)
        )
        #expect(high.score == 100)

        let low = engine.computeScore(
            from: input(sleepDelta: -5.0, hrvDelta: -9.0, restingHRDeltaBPM: 50, recentLoad: .heavy, recoveryConsistency: 0, feeling: .veryTired)
        )
        #expect(low.score >= 0)
        #expect(low.score <= 15)
    }

    @Test("Conflicting signals stay deterministic — great physiology, terrible feeling")
    func conflictingSignals() {
        let result = engine.computeScore(
            from: input(sleepDelta: 0, hrvDelta: 0, restingHRDeltaBPM: 0, recentLoad: .rest, recoveryConsistency: 1.0, feeling: .veryTired)
        )
        // 0.25 + 0.20 + 0.15 + 0.20 + 0.10 + 0 = 0.90
        #expect(result.score == 90)
        #expect(result.confidence == 1.0)
    }

    @Test("Low confidence adds an explanation fact about missing signals")
    func lowConfidenceFact() {
        let result = engine.computeScore(from: input(sleepDelta: 0))
        #expect(result.confidence < 0.7)
        #expect(result.explanationFacts.contains { $0.detail.contains("less certain") })
    }
}
