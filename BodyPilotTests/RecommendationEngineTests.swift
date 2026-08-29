import Foundation
import Testing
@testable import BodyPilot

struct RecommendationEngineTests {
    private let engine = RecommendationEngine()
    private let now = Date(timeIntervalSince1970: 1_769_817_600)

    private func score(readiness: ReadinessLevel) -> BodyScoreResult {
        let value: Int = switch readiness {
        case .strong: 85
        case .ready: 70
        case .easy: 55
        case .recover: 30
        }
        return BodyScoreResult(
            score: value, confidence: 0.9, readiness: readiness,
            components: [], explanationFacts: [], computedAt: now
        )
    }

    private func input(
        readiness: ReadinessLevel,
        preferredActivities: [ActivityType] = [.walking, .strength],
        preferredMinutes: Int = 30,
        equipment: [EquipmentType] = [.none],
        soreness: [SorenessArea] = [],
        feeling: FeelingLevel? = nil
    ) -> RecommendationInput {
        RecommendationInput(
            scoreResult: score(readiness: readiness),
            preferredActivities: preferredActivities,
            preferredWorkoutMinutes: preferredMinutes,
            equipment: equipment,
            soreness: soreness,
            feeling: feeling
        )
    }

    @Test("Recover days get gentle, short recommendations")
    func recoverDay() {
        let recommendation = engine.recommendation(for: input(readiness: .recover))
        #expect(recommendation.intensity == .recovery)
        #expect(recommendation.recommendedDuration.maxMinutes <= 20)
        #expect(recommendation.constraints.contains(.avoidHighIntensity))
        let allowed: Set<ActivityType> = [.recovery, .stretching, .mobility, .walking]
        #expect(recommendation.preferredActivities.allSatisfy(allowed.contains))
    }

    @Test("Strong days allow hard intensity and extended duration")
    func strongDay() {
        let recommendation = engine.recommendation(for: input(readiness: .strong, feeling: .good))
        #expect(recommendation.intensity == .hard)
        #expect(recommendation.recommendedDuration.minMinutes == 30)
        #expect(recommendation.recommendedDuration.maxMinutes == 45)
        #expect(!recommendation.constraints.contains(.avoidHighIntensity))
    }

    @Test("Feeling tired caps intensity at light even on a strong day")
    func tiredCapsIntensity() {
        let recommendation = engine.recommendation(for: input(readiness: .strong, feeling: .tired))
        #expect(recommendation.intensity == .light)
        #expect(recommendation.constraints.contains(.avoidHighIntensity))
    }

    @Test("Feeling very tired forces recovery intensity")
    func veryTiredForcesRecovery() {
        let recommendation = engine.recommendation(for: input(readiness: .ready, feeling: .veryTired))
        #expect(recommendation.intensity == .recovery)
    }

    @Test("General soreness caps intensity at light")
    func generalSorenessCaps() {
        let recommendation = engine.recommendation(for: input(readiness: .strong, soreness: [.general]))
        #expect(recommendation.intensity == .light)
    }

    @Test("Soreness areas become explicit constraints")
    func sorenessConstraints() {
        let recommendation = engine.recommendation(for: input(readiness: .ready, soreness: [.knee, .back]))
        #expect(recommendation.constraints.contains(.avoidSorenessArea(.knee)))
        #expect(recommendation.constraints.contains(.avoidSorenessArea(.back)))
    }

    @Test("Max-duration constraint always matches the recommended range")
    func maxDurationConstraint() {
        for readiness in ReadinessLevel.allCases {
            let recommendation = engine.recommendation(for: input(readiness: readiness))
            #expect(recommendation.constraints.contains(.maxDuration(minutes: recommendation.recommendedDuration.maxMinutes)))
            #expect(recommendation.recommendedDuration.minMinutes <= recommendation.recommendedDuration.maxMinutes)
        }
    }

    @Test("Equipment limits are carried as constraints")
    func equipmentConstraint() {
        let recommendation = engine.recommendation(for: input(readiness: .ready, equipment: [.dumbbells]))
        #expect(recommendation.constraints.contains(.equipmentLimit([.dumbbells])))
    }

    @Test("Ready days keep the user's preferred activities")
    func readyKeepsPreferences() {
        let recommendation = engine.recommendation(for: input(readiness: .ready, preferredActivities: [.cycling, .core]))
        #expect(recommendation.preferredActivities == [.cycling, .core])
    }

    @Test("Empty preferences fall back to walking")
    func emptyPreferencesFallback() {
        let recommendation = engine.recommendation(for: input(readiness: .ready, preferredActivities: []))
        #expect(recommendation.preferredActivities == [.walking])
    }

    @Test("Every recommendation ends with a plan rationale fact")
    func planFactPresent() {
        let recommendation = engine.recommendation(for: input(readiness: .easy))
        #expect(recommendation.rationaleFacts.last != nil)
    }
}
