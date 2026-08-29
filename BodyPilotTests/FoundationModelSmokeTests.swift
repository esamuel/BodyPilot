import Foundation
import FoundationModels
import Testing
@testable import BodyPilot

/// Live smoke checks for the on-device model. These pass trivially (with a
/// console note) where Apple Intelligence is unavailable, so CI and plain
/// simulators stay green; on capable hardware they exercise real generation.
struct FoundationModelSmokeTests {
    @Test("Insight explainer produces wording from a validated context when the model is available")
    func insightExplainerSmoke() async throws {
        guard case .available = SystemLanguageModel.default.availability else {
            print("FoundationModels unavailable here: \(SystemLanguageModel.default.availability)")
            return
        }

        let context = InsightContext(
            kind: .sleep,
            status: .low,
            facts: [
                ExplanationFact(title: "Last night", detail: "You slept 5h 50m."),
                ExplanationFact(title: "Vs your 28-day average", detail: "85 minutes less than your average of 7h 15m."),
            ],
            baselineComparisons: [
                BaselineComparison(label: "Sleep", todayText: "5h 50m", typicalText: "Usually 6h 45m–7h 45m", sevenDayTrend: .down),
            ],
            safeActions: ["Take an easy recovery session"],
            confidence: 0.85
        )

        let text = try await FoundationModelInsightExplainer().explain(context)
        print("INSIGHT EXPLAINER OUTPUT: \(text)")
        #expect(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test("When the model is unavailable, the real service degrades to the deterministic fallback")
    func fallbackEngagesWhenModelUnavailable() async throws {
        guard case .unavailable = SystemLanguageModel.default.availability else {
            print("Model available here — fallback path exercised elsewhere.")
            return
        }

        let context = AIContext(
            bodyScore: 72,
            confidence: 0.84,
            sleepDelta: -0.08,
            hrvDelta: nil,
            restingHRDeltaBPM: nil,
            recentLoad: .moderate,
            feeling: .normal,
            goal: .generalFitness,
            equipment: [.none]
        )
        let service = CoachService(primary: FoundationModelCoach())
        let response = await service.respond(
            to: CoachRequest(
                message: "Why is my score lower today?",
                context: context,
                constraints: [],
                profile: .dailyCoach
            )
        )
        #expect(response.source == .fallback)
        #expect(!response.text.isEmpty)
        print("FALLBACK OUTPUT: \(response.text)")
    }

    @Test("Coach answers a plain question through the full service when the model is available")
    func coachSmoke() async throws {
        guard case .available = SystemLanguageModel.default.availability else {
            print("FoundationModels unavailable here: \(SystemLanguageModel.default.availability)")
            return
        }

        let context = AIContext(
            bodyScore: 72,
            confidence: 0.84,
            sleepDelta: -0.08,
            hrvDelta: -0.05,
            restingHRDeltaBPM: 2,
            recentLoad: .moderate,
            feeling: .normal,
            goal: .walkingEndurance,
            equipment: [.none]
        )
        let service = CoachService(primary: FoundationModelCoach())
        let response = await service.respond(
            to: CoachRequest(
                message: "Why is my score lower today?",
                context: context,
                constraints: [.maxDuration(minutes: 30)],
                profile: .dailyCoach
            )
        )
        print("COACH SOURCE: \(response.source)")
        print("COACH OUTPUT: \(response.text)")
        #expect(!response.text.isEmpty)
    }
}
