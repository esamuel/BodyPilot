import Foundation
import Testing
@testable import BodyPilot

@MainActor
struct StreakEngineTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    private let now = Date(timeIntervalSince1970: 1_769_817_600)

    private func day(
        daysAgo: Int,
        state: CorridorState,
        load: Double = 100,
        rest: Bool = false
    ) -> CorridorDay {
        let date = Self.calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        return CorridorDay(
            date: date,
            lowerBound: rest ? 0 : 60,
            upperBound: 140,
            load: load,
            state: state,
            isRestRecommended: rest
        )
    }

    @Test("Inside and prescribed rest days grow the streak")
    func successfulDays() {
        let result = StreakEngine(calendar: Self.calendar).streak(
            days: [
                day(daysAgo: 2, state: .inside),
                day(daysAgo: 1, state: .inside, load: 0, rest: true),
                day(daysAgo: 0, state: .inside),
            ],
            asOf: now
        )

        #expect(result.count == 3)
    }

    @Test("An unfinished current day preserves the existing streak")
    func unfinishedTodayPreservesStreak() {
        let result = StreakEngine(calendar: Self.calendar).streak(
            days: [
                day(daysAgo: 2, state: .inside),
                day(daysAgo: 1, state: .inside),
                day(daysAgo: 0, state: .below, load: 0),
            ],
            asOf: now
        )

        #expect(result.count == 2)
    }

    @Test("A completed missed day breaks the streak")
    func missedCompletedDayBreaksStreak() {
        let result = StreakEngine(calendar: Self.calendar).streak(
            days: [
                day(daysAgo: 2, state: .inside),
                day(daysAgo: 1, state: .below, load: 0),
                day(daysAgo: 0, state: .below, load: 0),
            ],
            asOf: now
        )

        #expect(result.count == 0)
    }

    @Test("Two consecutive above days break the streak")
    func repeatedOverreachBreaks() {
        let result = StreakEngine(calendar: Self.calendar).streak(
            days: [
                day(daysAgo: 3, state: .inside),
                day(daysAgo: 2, state: .inside),
                day(daysAgo: 1, state: .above, load: 180),
                day(daysAgo: 0, state: .above, load: 180),
            ],
            asOf: now
        )

        #expect(result.count == 0)
        #expect(result.consecutiveAboveDays == 2)
    }

    @Test("Active Life Status freezes and preserves the streak")
    func activeStatusFreezes() {
        let status = LifeStatus(kind: .sick, startDate: now)
        let result = StreakEngine(calendar: Self.calendar).streak(
            days: [
                day(daysAgo: 1, state: .inside),
                day(daysAgo: 0, state: .below, load: 0),
            ],
            lifeStatuses: [status],
            asOf: now
        )

        #expect(result.isFrozen)
        #expect(result.count == 1)
    }

    @Test("Future corridor days are ignored")
    func futureDaysAreIgnored() {
        let future = CorridorDay(
            date: Self.calendar.date(byAdding: .day, value: 1, to: now) ?? now,
            lowerBound: 60,
            upperBound: 140,
            load: 100,
            state: .inside,
            isRestRecommended: false
        )
        let result = StreakEngine(calendar: Self.calendar).streak(
            days: [
                day(daysAgo: 1, state: .inside),
                day(daysAgo: 0, state: .inside),
                future,
            ],
            asOf: now
        )

        #expect(result.count == 2)
    }
}
