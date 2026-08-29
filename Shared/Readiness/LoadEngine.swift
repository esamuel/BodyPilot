import Foundation

/// Centralized, tunable thresholds for load and consistency classification.
struct LoadConfiguration: Sendable {
    /// Window for classifying recent training load.
    let loadWindowDays: Int
    /// Total workout minutes in the window below which load counts as light.
    let lightMaxMinutes: Double
    /// Total workout minutes in the window below which load counts as moderate.
    let moderateMaxMinutes: Double
    /// Window for measuring activity/rest consistency.
    let consistencyWindowDays: Int
    /// Days with usable data required before consistency is reported at all.
    let consistencyMinimumDays: Int
    /// Minutes of exercise that make a day count as active.
    let activeDayMinimumMinutes: Double
    /// Active days per week considered ideal for sustainable training.
    let idealActiveDaysPerWeek: Double

    static let `default` = LoadConfiguration(
        loadWindowDays: 7,
        lightMaxMinutes: 90,
        moderateMaxMinutes: 240,
        consistencyWindowDays: 14,
        consistencyMinimumDays: 7,
        activeDayMinimumMinutes: 10,
        idealActiveDaysPerWeek: 4
    )
}

/// Deterministic classification of recent training load and recovery consistency.
struct LoadEngine: Sendable {
    let configuration: LoadConfiguration
    let calendar: Calendar

    init(configuration: LoadConfiguration = .default, calendar: Calendar = .current) {
        self.configuration = configuration
        self.calendar = calendar
    }

    /// Classifies total workout minutes over the load window ending at `date`.
    func recentLoad(workouts: [WorkoutSummary], asOf date: Date) -> TrainingLoad {
        guard let windowStart = calendar.date(byAdding: .day, value: -configuration.loadWindowDays, to: date) else {
            return .rest
        }
        let minutes = workouts
            .filter { $0.start >= windowStart && $0.start <= date }
            .reduce(0) { $0 + $1.durationMinutes }

        return switch minutes {
        case ..<1: .rest
        case ..<configuration.lightMaxMinutes: .light
        case ..<configuration.moderateMaxMinutes: .moderate
        default: .heavy
        }
    }

    /// 0–1 measure of how close the user's active-day rhythm is to the sustainable
    /// ideal. Nil when the window holds too little data to judge.
    func recoveryConsistency(snapshots: [DailyHealthSnapshot], asOf date: Date) -> Double? {
        let cutoff = calendar.startOfDay(for: date)
        guard let windowStart = calendar.date(byAdding: .day, value: -configuration.consistencyWindowDays, to: cutoff) else {
            return nil
        }
        let window = snapshots.filter { $0.date >= windowStart && $0.date < cutoff }
        let daysWithData = window.filter { $0.exerciseMinutes != nil }
        guard daysWithData.count >= configuration.consistencyMinimumDays else { return nil }

        let activeDays = daysWithData.filter { ($0.exerciseMinutes ?? 0) >= configuration.activeDayMinimumMinutes }
        let activePerWeek = Double(activeDays.count) / Double(configuration.consistencyWindowDays) * 7
        let deviation = abs(activePerWeek - configuration.idealActiveDaysPerWeek) / configuration.idealActiveDaysPerWeek
        return min(max(1 - deviation, 0), 1)
    }
}
