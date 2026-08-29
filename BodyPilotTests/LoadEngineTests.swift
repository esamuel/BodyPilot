import Foundation
import Testing
@testable import BodyPilot

struct LoadEngineTests {
    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    private let engine = LoadEngine(calendar: utcCalendar)
    private let now = Date(timeIntervalSince1970: 1_769_817_600)

    private func workout(daysAgo: Int, minutes: Double) -> WorkoutSummary {
        WorkoutSummary(
            start: now.addingTimeInterval(Double(-daysAgo) * 86_400),
            durationMinutes: minutes,
            activity: .walking,
            totalEnergyKilocalories: nil
        )
    }

    @Test("No workouts classifies as rest")
    func noWorkouts() {
        #expect(engine.recentLoad(workouts: [], asOf: now) == .rest)
    }

    @Test("Workout minutes map to the configured load bands")
    func loadBands() {
        #expect(engine.recentLoad(workouts: [workout(daysAgo: 2, minutes: 60)], asOf: now) == .light)
        #expect(
            engine.recentLoad(
                workouts: [workout(daysAgo: 1, minutes: 60), workout(daysAgo: 3, minutes: 60)],
                asOf: now
            ) == .moderate
        )
        #expect(
            engine.recentLoad(
                workouts: [workout(daysAgo: 1, minutes: 150), workout(daysAgo: 2, minutes: 150)],
                asOf: now
            ) == .heavy
        )
    }

    @Test("Workouts outside the 7-day window are ignored")
    func windowBoundary() {
        #expect(engine.recentLoad(workouts: [workout(daysAgo: 10, minutes: 300)], asOf: now) == .rest)
    }

    private func snapshot(daysAgo: Int, exerciseMinutes: Double?) -> DailyHealthSnapshot {
        DailyHealthSnapshot(
            date: Self.utcCalendar.startOfDay(for: now).addingTimeInterval(Double(-daysAgo) * 86_400),
            sleepHours: nil, hrvSDNN: nil, restingHeartRate: nil,
            steps: nil, activeEnergyKilocalories: nil, exerciseMinutes: exerciseMinutes
        )
    }

    @Test("Four active days per week is ideal consistency")
    func idealConsistency() throws {
        // 8 active days in 14 = 4 per week.
        let snapshots = (1...14).map { day in
            snapshot(daysAgo: day, exerciseMinutes: day <= 8 ? 30 : 0)
        }
        let consistency = try #require(engine.recoveryConsistency(snapshots: snapshots, asOf: now))
        #expect(abs(consistency - 1.0) < 0.000_1)
    }

    @Test("No active days yields zero consistency")
    func zeroConsistency() throws {
        let snapshots = (1...14).map { snapshot(daysAgo: $0, exerciseMinutes: 0) }
        let consistency = try #require(engine.recoveryConsistency(snapshots: snapshots, asOf: now))
        #expect(consistency == 0)
    }

    @Test("Too little data yields no consistency value")
    func insufficientConsistencyData() {
        let snapshots = (1...5).map { snapshot(daysAgo: $0, exerciseMinutes: 30) }
            + (6...14).map { snapshot(daysAgo: $0, exerciseMinutes: nil) }
        #expect(engine.recoveryConsistency(snapshots: snapshots, asOf: now) == nil)
    }
}
