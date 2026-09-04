import Foundation
import Testing
@testable import BodyPilot

struct HeartRateLoadTests {
    private let now = Date(timeIntervalSince1970: 1_769_817_600)

    @Test("Dense heart-rate samples use HR-reserve zone weights")
    func denseHeartRate() {
        let sample = WorkoutHeartRateSample(
            start: now,
            end: now.addingTimeInterval(30 * 60),
            beatsPerMinute: 150
        )
        let workout = WorkoutSummary(
            start: now,
            durationMinutes: 30,
            activity: .walking,
            totalEnergyKilocalories: nil,
            heartRateSamples: [sample]
        )

        let load = LoadEngine().workoutLoad(
            for: workout,
            restingHeartRate: 60,
            maximumHeartRate: 190
        )

        #expect(load == 90)
    }

    @Test("Sparse heart-rate samples use the activity fallback")
    func sparseHeartRate() {
        let sample = WorkoutHeartRateSample(
            start: now,
            end: now.addingTimeInterval(5 * 60),
            beatsPerMinute: 150
        )
        let workout = WorkoutSummary(
            start: now,
            durationMinutes: 30,
            activity: .walking,
            totalEnergyKilocalories: nil,
            heartRateSamples: [sample]
        )

        #expect(LoadEngine().workoutLoad(for: workout) == 120)
    }

    @Test("RPE overrides dense heart-rate load")
    func rpeOverride() {
        let sample = WorkoutHeartRateSample(
            start: now,
            end: now.addingTimeInterval(30 * 60),
            beatsPerMinute: 150
        )
        let workout = WorkoutSummary(
            start: now,
            durationMinutes: 30,
            activity: .walking,
            totalEnergyKilocalories: nil,
            heartRateSamples: [sample],
            perceivedExertion: 8
        )

        #expect(LoadEngine().workoutLoad(for: workout) == 240)
    }
}
