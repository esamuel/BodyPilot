import Foundation
import Testing
@testable import BodyPilot

@MainActor
struct RecapEngineTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    private let now = Date(timeIntervalSince1970: 1_769_817_600)

    @Test("Weekly recap aggregates activity, distance, load, energy, and photos")
    func weeklyRecap() throws {
        let workoutID = UUID()
        let workout = WorkoutSummary(
            id: workoutID,
            start: now.addingTimeInterval(-86_400),
            durationMinutes: 30,
            activity: .walking,
            totalEnergyKilocalories: 180
        )
        let snapshot = DailyHealthSnapshot(
            date: now.addingTimeInterval(-86_400),
            sleepHours: nil,
            hrvSDNN: nil,
            restingHeartRate: nil,
            steps: 6_000,
            activeEnergyKilocalories: 300,
            exerciseMinutes: 30,
            walkingRunningDistanceMeters: 4_000
        )
        let journal = WorkoutJournalEntry(
            workoutID: workoutID,
            perceivedExertion: 7,
            photoIdentifiers: ["one", "two"]
        )

        let summaries = RecapEngine(
            loadEngine: LoadEngine(calendar: Self.calendar),
            calendar: Self.calendar
        ).summaries(
            snapshots: [snapshot],
            workouts: [workout],
            journalEntries: [journal],
            asOf: now
        )
        let week = try #require(summaries.first { $0.period == .week })

        #expect(week.activeDays == 1)
        #expect(week.workoutCount == 1)
        #expect(week.distanceMeters == 4_000)
        #expect(week.energyKilocalories == 180)
        #expect(week.photoCount == 2)
        #expect(week.currentLoad > 0)
    }
}
