import Foundation

/// Counts consecutive days on which the user followed the healthy-load plan.
/// Active Life Status days are skipped, and an unfinished current day cannot break
/// an existing streak.
struct StreakEngine: Sendable {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func streak(
        days: [CorridorDay],
        lifeStatuses: [LifeStatus] = [],
        asOf date: Date
    ) -> StreakResult {
        let today = calendar.startOfDay(for: date)
        let eligibleDays = days
            .filter { calendar.startOfDay(for: $0.date) <= today }
            .sorted { $0.date > $1.date }
            .filter {
                LifeStatusResolver.activeStatus(
                    in: lifeStatuses,
                    at: $0.date,
                    calendar: calendar
                ) == nil
            }

        var count = 0
        for day in eligibleDays {
            let isToday = calendar.isDate(day.date, inSameDayAs: today)
            if followsPlan(day) {
                count += 1
            } else if !isToday {
                break
            }
        }

        return StreakResult(
            count: count,
            isFrozen: LifeStatusResolver.activeStatus(
                in: lifeStatuses,
                at: date,
                calendar: calendar
            ) != nil,
            consecutiveAboveDays: consecutiveAboveDays(in: eligibleDays)
        )
    }

    private func followsPlan(_ day: CorridorDay) -> Bool {
        day.state == .inside || (day.isRestRecommended && day.load == 0)
    }

    private func consecutiveAboveDays(in days: [CorridorDay]) -> Int {
        days.prefix { $0.state == .above }.count
    }
}
