import Foundation
import Testing
@testable import BodyPilot

struct ProgressEngineTests {
    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    private let engine = ProgressEngine(calendar: utcCalendar)
    private let now = Date(timeIntervalSince1970: 1_769_817_600)

    private func snapshot(daysAgo: Int, sleep: Double? = nil, hrv: Double? = nil, restingHR: Double? = nil, exercise: Double? = nil) -> DailyHealthSnapshot {
        DailyHealthSnapshot(
            date: now.addingTimeInterval(Double(-daysAgo) * 86_400),
            sleepHours: sleep, hrvSDNN: hrv, restingHeartRate: restingHR,
            steps: nil, activeEnergyKilocalories: nil, exerciseMinutes: exercise
        )
    }

    private func workout(daysAgo: Int, minutes: Double, activity: ActivityType?) -> WorkoutSummary {
        WorkoutSummary(
            start: now.addingTimeInterval(Double(-daysAgo) * 86_400),
            durationMinutes: minutes,
            activity: activity,
            totalEnergyKilocalories: nil
        )
    }

    @Test("Workouts aggregate into count, minutes, strength, and cardio")
    func workoutAggregation() throws {
        let workouts = [
            workout(daysAgo: 1, minutes: 30, activity: .walking),
            workout(daysAgo: 2, minutes: 20, activity: .strength),
            workout(daysAgo: 3, minutes: 25, activity: .cycling),
            workout(daysAgo: 4, minutes: 15, activity: nil),
        ]
        let summary = try #require(engine.summary(snapshots: [], workouts: workouts, period: .week, asOf: now))
        #expect(summary.workoutCount == 4)
        #expect(summary.totalWorkoutMinutes == 90)
        #expect(summary.strengthSessions == 1)
        #expect(summary.cardioMinutes == 55)
    }

    @Test("Workouts outside the period are excluded")
    func windowBoundary() throws {
        let workouts = [
            workout(daysAgo: 2, minutes: 30, activity: .walking),
            workout(daysAgo: 10, minutes: 60, activity: .walking),
        ]
        let summary = try #require(engine.summary(snapshots: [], workouts: workouts, period: .week, asOf: now))
        #expect(summary.workoutCount == 1)
        #expect(summary.totalWorkoutMinutes == 30)
    }

    @Test("Active days respect the minimum-minutes threshold")
    func activeDays() throws {
        let snapshots = [
            snapshot(daysAgo: 1, exercise: 30),
            snapshot(daysAgo: 2, exercise: 5),
            snapshot(daysAgo: 3, exercise: 12),
            snapshot(daysAgo: 4, exercise: nil),
        ]
        let summary = try #require(engine.summary(snapshots: snapshots, workouts: [], period: .week, asOf: now))
        #expect(summary.activeDays == 2)
        #expect(summary.dailyActiveMinutes.count == 4)
    }

    @Test("Trends compare current vs previous period averages")
    func trendComparison() throws {
        let snapshots = (1...7).map { snapshot(daysAgo: $0, sleep: 8) }
            + (8...14).map { snapshot(daysAgo: $0, sleep: 7) }
        let summary = try #require(engine.summary(snapshots: snapshots, workouts: [], period: .week, asOf: now))
        let sleep = try #require(summary.sleepTrend)
        #expect(sleep.currentAverage == 8)
        #expect(sleep.previousAverage == 7)
        let change = try #require(sleep.changeFraction)
        #expect(abs(change - (1.0 / 7.0)) < 0.000_1)
    }

    @Test("Missing current data yields no trend; missing previous data yields no change")
    func missingTrendData() throws {
        let onlyPrevious = (8...14).map { snapshot(daysAgo: $0, hrv: 50) }
        let summaryA = try #require(engine.summary(snapshots: onlyPrevious, workouts: [], period: .week, asOf: now))
        #expect(summaryA.hrvTrend == nil)

        let onlyCurrent = (1...7).map { snapshot(daysAgo: $0, hrv: 50) }
        let summaryB = try #require(engine.summary(snapshots: onlyCurrent, workouts: [], period: .week, asOf: now))
        let hrv = try #require(summaryB.hrvTrend)
        #expect(hrv.previousAverage == nil)
        #expect(hrv.changeFraction == nil)
    }

    @Test("Empty inputs produce an explicitly empty summary")
    func emptyInputs() throws {
        let summary = try #require(engine.summary(snapshots: [], workouts: [], period: .month, asOf: now))
        #expect(!summary.hasAnyData)
        #expect(summary.workoutCount == 0)
        #expect(summary.sleepTrend == nil)
    }
}
