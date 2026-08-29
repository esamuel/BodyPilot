import Foundation

/// Reporting periods per PRD 7.9.
enum ProgressPeriod: Int, CaseIterable, Sendable {
    case week = 7
    case month = 30
    case quarter = 90
}

/// Average of a metric in the current period compared with the previous one.
struct MetricTrend: Hashable, Sendable {
    let currentAverage: Double
    let previousAverage: Double?

    /// Relative change vs the previous period; nil without meaningful previous data.
    var changeFraction: Double? {
        guard let previousAverage, previousAverage > 0 else { return nil }
        return (currentAverage - previousAverage) / previousAverage
    }
}

/// Aggregated history for one reporting period.
struct ProgressSummary: Sendable {
    let periodDays: Int
    let workoutCount: Int
    let totalWorkoutMinutes: Double
    let strengthSessions: Int
    let cardioMinutes: Double
    let activeDays: Int
    let dailyActiveMinutes: [DatedValue]
    let sleepTrend: MetricTrend?
    let hrvTrend: MetricTrend?
    let restingHRTrend: MetricTrend?

    var hasAnyData: Bool {
        workoutCount > 0 || activeDays > 0
            || sleepTrend != nil || hrvTrend != nil || restingHRTrend != nil
    }
}

/// Deterministic aggregation of health history for the Progress screen.
struct ProgressEngine: Sendable {
    let calendar: Calendar
    /// Minutes of exercise that make a day count as active (matches LoadEngine).
    private let activeDayMinimumMinutes = LoadConfiguration.default.activeDayMinimumMinutes
    private static let cardioActivities: Set<ActivityType> = [.walking, .running, .cycling, .swimming]

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func summary(
        snapshots: [DailyHealthSnapshot],
        workouts: [WorkoutSummary],
        period: ProgressPeriod,
        asOf date: Date
    ) -> ProgressSummary? {
        guard let currentStart = calendar.date(byAdding: .day, value: -period.rawValue, to: date),
              let previousStart = calendar.date(byAdding: .day, value: -2 * period.rawValue, to: date) else {
            return nil
        }

        // Windows are inclusive at their older edge so a sample landing exactly
        // on a boundary belongs to the newer period, never both and never neither.
        let current = snapshots.filter { $0.date >= currentStart && $0.date <= date }
        let previous = snapshots.filter { $0.date >= previousStart && $0.date < currentStart }
        let periodWorkouts = workouts.filter { $0.start >= currentStart && $0.start <= date }

        return ProgressSummary(
            periodDays: period.rawValue,
            workoutCount: periodWorkouts.count,
            totalWorkoutMinutes: periodWorkouts.reduce(0) { $0 + $1.durationMinutes },
            strengthSessions: periodWorkouts.count { $0.activity == .strength },
            cardioMinutes: periodWorkouts
                .filter { $0.activity.map(Self.cardioActivities.contains) ?? false }
                .reduce(0) { $0 + $1.durationMinutes },
            activeDays: current.count { ($0.exerciseMinutes ?? 0) >= activeDayMinimumMinutes },
            dailyActiveMinutes: current
                .map { DatedValue(date: $0.date, value: $0.exerciseMinutes ?? 0) }
                .sorted { $0.date < $1.date },
            sleepTrend: trend(current: current, previous: previous, keyPath: \.sleepHours),
            hrvTrend: trend(current: current, previous: previous, keyPath: \.hrvSDNN),
            restingHRTrend: trend(current: current, previous: previous, keyPath: \.restingHeartRate)
        )
    }

    private func trend(
        current: [DailyHealthSnapshot],
        previous: [DailyHealthSnapshot],
        keyPath: KeyPath<DailyHealthSnapshot, Double?>
    ) -> MetricTrend? {
        guard let currentAverage = average(current.compactMap { $0[keyPath: keyPath] }) else {
            return nil
        }
        return MetricTrend(
            currentAverage: currentAverage,
            previousAverage: average(previous.compactMap { $0[keyPath: keyPath] })
        )
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
