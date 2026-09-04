import Foundation
import Testing
@testable import BodyPilot

@MainActor
struct CorridorEngineTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    private let now = Date(timeIntervalSince1970: 1_769_817_600)

    private func workout(daysAgo: Int, minutes: Double = 25) -> WorkoutSummary {
        WorkoutSummary(
            start: Self.calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now,
            durationMinutes: minutes,
            activity: .walking,
            totalEnergyKilocalories: nil
        )
    }

    @Test("A sustainable repeated load lands inside the corridor")
    func repeatedLoadIsInside() throws {
        let workouts = (0..<60).map { workout(daysAgo: $0) }
        let engine = CorridorEngine(
            loadEngine: LoadEngine(calendar: Self.calendar),
            baselineEngine: BaselineEngine(calendar: Self.calendar),
            calendar: Self.calendar
        )
        let corridor = engine.corridor(
            window: .tenDays,
            snapshots: [],
            workouts: workouts,
            asOf: now
        )
        let today = try #require(corridor.today)

        #expect(corridor.days.count == 10)
        #expect(today.state == .inside)
        #expect(today.lowerBound < today.load)
        #expect(today.load < today.upperBound)
    }

    @Test("Life Status pauses presentation without changing load")
    func lifeStatusPausesCorridor() {
        let status = LifeStatus(kind: .vacation, startDate: now)
        let corridor = CorridorEngine(calendar: Self.calendar).corridor(
            window: .day,
            snapshots: [],
            workouts: [workout(daysAgo: 0)],
            lifeStatuses: [status],
            asOf: now
        )

        #expect(corridor.isPaused)
        #expect(corridor.today?.load == 100)
    }
}
