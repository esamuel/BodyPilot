import Testing
@testable import BodyPilot

struct ReadinessLevelTests {
    @Test("Body Score maps to the PRD readiness bands, including boundaries")
    func bandMapping() {
        #expect(ReadinessLevel(bodyScore: 100) == .strong)
        #expect(ReadinessLevel(bodyScore: 80) == .strong)
        #expect(ReadinessLevel(bodyScore: 79) == .ready)
        #expect(ReadinessLevel(bodyScore: 65) == .ready)
        #expect(ReadinessLevel(bodyScore: 64) == .easy)
        #expect(ReadinessLevel(bodyScore: 45) == .easy)
        #expect(ReadinessLevel(bodyScore: 44) == .recover)
        #expect(ReadinessLevel(bodyScore: 0) == .recover)
    }

    @Test("Out-of-range scores clamp to the nearest band")
    func outOfRangeClamping() {
        #expect(ReadinessLevel(bodyScore: 150) == .strong)
        #expect(ReadinessLevel(bodyScore: -10) == .recover)
    }
}

struct BodyScoreWeightsTests {
    @Test("Default weights sum to 1.0")
    func defaultWeightsSumToOne() {
        #expect(abs(BodyScoreWeights.default.total - 1.0) < 0.000_1)
    }

    @Test("Default weights match the PRD section 7.3 specification")
    func defaultWeightsMatchPRD() {
        let weights = BodyScoreWeights.default
        #expect(weights.weight(for: .sleep) == 0.25)
        #expect(weights.weight(for: .hrv) == 0.20)
        #expect(weights.weight(for: .restingHeartRate) == 0.15)
        #expect(weights.weight(for: .recentLoad) == 0.20)
        #expect(weights.weight(for: .recoveryHistory) == 0.10)
        #expect(weights.weight(for: .subjectiveFeeling) == 0.10)
    }
}
