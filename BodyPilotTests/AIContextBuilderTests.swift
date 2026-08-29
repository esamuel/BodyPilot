import Foundation
import Testing
@testable import BodyPilot

struct AIContextBuilderTests {
    private let builder = AIContextBuilder()
    private let now = Date(timeIntervalSince1970: 1_769_817_600)

    private func score(_ value: Int, confidence: Double = 0.845) -> BodyScoreResult {
        BodyScoreResult(
            score: value, confidence: confidence, readiness: ReadinessLevel(bodyScore: value),
            components: [], explanationFacts: [], computedAt: now
        )
    }

    @Test("Context carries derived values, rounded to coarse precision")
    func mappingAndRounding() {
        let context = builder.makeContext(
            score: score(72),
            deltas: BaselineDeltas(sleepDelta: -0.08349, hrvDelta: -0.0511, restingHRDeltaBPM: 2.4),
            recentLoad: .moderate,
            feeling: .normal,
            goal: .walkingEndurance,
            equipment: [.none],
            preferredActivities: [.walking, .mobility],
            preferredWorkoutMinutes: 25
        )
        #expect(context.bodyScore == 72)
        #expect(context.confidence == 0.85)
        #expect(context.sleepDelta == -0.08)
        #expect(context.hrvDelta == -0.05)
        #expect(context.restingHRDeltaBPM == 2)
        #expect(context.recentLoad == .moderate)
        #expect(context.goal == .walkingEndurance)
        #expect(context.preferredActivities == [.walking, .mobility])
        #expect(context.preferredWorkoutMinutes == 25)
    }

    @Test("Missing signals stay nil and a missing feeling defaults to normal")
    func missingValues() {
        let context = builder.makeContext(
            score: score(50, confidence: 0),
            deltas: BaselineDeltas(sleepDelta: nil, hrvDelta: nil, restingHRDeltaBPM: nil),
            recentLoad: .rest,
            feeling: nil,
            goal: .generalFitness,
            equipment: [.none],
            preferredActivities: [.walking],
            preferredWorkoutMinutes: 30
        )
        #expect(context.sleepDelta == nil)
        #expect(context.hrvDelta == nil)
        #expect(context.restingHRDeltaBPM == nil)
        #expect(context.feeling == .normal)
    }

    @Test("The prompt block lists constraints as never-exceed rules")
    func promptBlockIncludesConstraints() {
        let context = builder.makeContext(
            score: score(55),
            deltas: BaselineDeltas(sleepDelta: -0.1, hrvDelta: nil, restingHRDeltaBPM: nil),
            recentLoad: .light,
            feeling: .tired,
            goal: .generalFitness,
            equipment: [.none],
            preferredActivities: [.strength],
            preferredWorkoutMinutes: 20
        )
        let block = CoachPromptFormatter.contextBlock(
            for: context,
            constraints: [.maxDuration(minutes: 20), .avoidHighIntensity, .avoidSorenessArea(.knee)]
        )
        #expect(block.contains("Body Score: 55"))
        #expect(block.contains("maximum 20 minutes"))
        #expect(block.contains("no high-intensity work today"))
        #expect(block.contains("knee"))
        #expect(block.contains("never be exceeded"))
        #expect(block.contains("Sleep vs. baseline: -10%"))
        #expect(block.contains("Preferred activities: strength"))
        #expect(block.contains("Preferred workout length: 20 minutes"))
    }
}
