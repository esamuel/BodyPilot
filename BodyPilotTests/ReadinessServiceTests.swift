import Foundation
import Testing
@testable import BodyPilot

struct ReadinessServiceTests {
    private let service = ReadinessService(healthMetrics: MockHealthProvider())
    private let now = Date(timeIntervalSince1970: 1_769_817_600)

    @Test("The pipeline produces a score and recommendation from mock data")
    func producesSnapshot() async throws {
        let snapshot = try await service.snapshot(
            preferences: .default,
            feeling: .normal,
            soreness: [],
            now: now
        )
        #expect((0...100).contains(snapshot.score.score))
        #expect(snapshot.score.confidence > 0)
        #expect(!snapshot.recommendation.constraints.isEmpty)
        #expect(!snapshot.recommendation.preferredActivities.isEmpty)
    }

    @Test("Identical inputs produce identical snapshots")
    func deterministic() async throws {
        let first = try await service.snapshot(preferences: .default, feeling: .good, soreness: [], now: now)
        let second = try await service.snapshot(preferences: .default, feeling: .good, soreness: [], now: now)
        #expect(first.score.score == second.score.score)
        #expect(first.score.confidence == second.score.confidence)
        #expect(first.recommendation.intensity == second.recommendation.intensity)
    }

    @Test("A tired check-in caps the recommended intensity")
    func tiredCapsIntensity() async throws {
        let snapshot = try await service.snapshot(
            preferences: .default,
            feeling: .tired,
            soreness: [],
            now: now
        )
        #expect(snapshot.recommendation.intensity.rank <= WorkoutIntensity.light.rank)
    }

    @Test("Soreness flows through to the recommendation constraints")
    func sorenessFlowsThrough() async throws {
        let snapshot = try await service.snapshot(
            preferences: .default,
            feeling: .normal,
            soreness: [.knee],
            now: now
        )
        #expect(snapshot.recommendation.constraints.contains(.avoidSorenessArea(.knee)))
    }
}
