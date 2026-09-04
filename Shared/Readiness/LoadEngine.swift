import Foundation

/// Centralized, tunable constants for heart-rate load and consistency.
struct LoadConfiguration: Sendable {
    let loadWindowDays: Int
    let lightMaxLoad: Double
    let moderateMaxLoad: Double
    let consistencyWindowDays: Int
    let consistencyMinimumDays: Int
    let activeDayMinimumMinutes: Double
    let idealActiveDaysPerWeek: Double
    let minimumHeartRateCoverage: Double
    let defaultRestingHeartRate: Double
    let minimumEstimatedMaxHeartRate: Double
    let observedPeakReserve: Double
    let defaultRPE: Double
    let heartRateReserveZoneThresholds: [Double]
    let heartRateZoneWeights: [Double]

    static let `default` = LoadConfiguration(
        loadWindowDays: 7,
        lightMaxLoad: 450,
        moderateMaxLoad: 1_200,
        consistencyWindowDays: 14,
        consistencyMinimumDays: 7,
        activeDayMinimumMinutes: 10,
        idealActiveDaysPerWeek: 4,
        minimumHeartRateCoverage: 0.5,
        defaultRestingHeartRate: 60,
        minimumEstimatedMaxHeartRate: 170,
        observedPeakReserve: 1.02,
        defaultRPE: 5,
        heartRateReserveZoneThresholds: [0.5, 0.6, 0.7, 0.8, 0.9],
        heartRateZoneWeights: [1, 2, 3, 4, 5, 6]
    )

    func activityWeight(for activity: ActivityType?) -> Double {
        switch activity {
        case .walking: 0.8
        case .running: 1.2
        case .cycling: 1
        case .strength: 1.1
        case .swimming: 1.1
        case .core: 0.9
        case .mobility, .balance, .stretching, .chairExercise, .recovery: 0.6
        case nil: 1
        }
    }
}

/// Deterministic training-load calculation. Explicit RPE is authoritative;
/// otherwise sufficiently dense heart-rate samples use HR-reserve zones.
struct LoadEngine: Sendable {
    let configuration: LoadConfiguration
    let calendar: Calendar

    init(configuration: LoadConfiguration = .default, calendar: Calendar = .current) {
        self.configuration = configuration
        self.calendar = calendar
    }

    func workoutLoad(
        for workout: WorkoutSummary,
        restingHeartRate: Double? = nil,
        maximumHeartRate: Double? = nil
    ) -> Double {
        guard workout.durationMinutes > 0 else { return 0 }

        if let rpe = workout.perceivedExertion {
            return workout.durationMinutes * Double(min(max(rpe, 1), 10))
        }

        let coveredMinutes = workout.heartRateSamples.reduce(0) { $0 + $1.durationMinutes }
        let coverage = min(coveredMinutes / workout.durationMinutes, 1)
        guard coverage >= configuration.minimumHeartRateCoverage else {
            return fallbackLoad(for: workout)
        }

        let resting = restingHeartRate ?? configuration.defaultRestingHeartRate
        let observedPeak = workout.heartRateSamples.map(\.beatsPerMinute).max() ?? 0
        let estimatedMaximum = max(
            maximumHeartRate ?? 0,
            configuration.minimumEstimatedMaxHeartRate,
            observedPeak * configuration.observedPeakReserve
        )
        guard estimatedMaximum > resting else {
            return fallbackLoad(for: workout)
        }

        return workout.heartRateSamples.reduce(0) { load, sample in
            let reserveFraction = (sample.beatsPerMinute - resting) / (estimatedMaximum - resting)
            return load + sample.durationMinutes * zoneWeight(for: reserveFraction)
        }
    }

    func dailyLoad(
        workouts: [WorkoutSummary],
        on date: Date,
        restingHeartRate: Double? = nil,
        maximumHeartRate: Double? = nil
    ) -> Double {
        let day = calendar.startOfDay(for: date)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return 0 }
        return workouts
            .filter { $0.start >= day && $0.start < nextDay }
            .reduce(0) {
                $0 + workoutLoad(
                    for: $1,
                    restingHeartRate: restingHeartRate,
                    maximumHeartRate: maximumHeartRate
                )
            }
    }

    func recentLoad(
        workouts: [WorkoutSummary],
        asOf date: Date,
        restingHeartRate: Double? = nil,
        maximumHeartRate: Double? = nil
    ) -> TrainingLoad {
        guard let windowStart = calendar.date(byAdding: .day, value: -configuration.loadWindowDays, to: date) else {
            return .rest
        }
        let load = workouts
            .filter { $0.start >= windowStart && $0.start <= date }
            .reduce(0) {
                $0 + workoutLoad(
                    for: $1,
                    restingHeartRate: restingHeartRate,
                    maximumHeartRate: maximumHeartRate
                )
            }

        return switch load {
        case ..<1: .rest
        case ..<configuration.lightMaxLoad: .light
        case ..<configuration.moderateMaxLoad: .moderate
        default: .heavy
        }
    }

    func recoveryConsistency(snapshots: [DailyHealthSnapshot], asOf date: Date) -> Double? {
        let cutoff = calendar.startOfDay(for: date)
        guard let windowStart = calendar.date(byAdding: .day, value: -configuration.consistencyWindowDays, to: cutoff) else {
            return nil
        }
        let window = snapshots.filter { $0.date >= windowStart && $0.date < cutoff }
        let daysWithData = window.filter { $0.exerciseMinutes != nil }
        guard daysWithData.count >= configuration.consistencyMinimumDays else { return nil }

        let activeDays = daysWithData.filter {
            ($0.exerciseMinutes ?? 0) >= configuration.activeDayMinimumMinutes
        }
        let activePerWeek = Double(activeDays.count) / Double(configuration.consistencyWindowDays) * 7
        let deviation = abs(activePerWeek - configuration.idealActiveDaysPerWeek)
            / configuration.idealActiveDaysPerWeek
        return min(max(1 - deviation, 0), 1)
    }

    private func fallbackLoad(for workout: WorkoutSummary) -> Double {
        workout.durationMinutes
            * configuration.activityWeight(for: workout.activity)
            * configuration.defaultRPE
    }

    private func zoneWeight(for reserveFraction: Double) -> Double {
        let index = configuration.heartRateReserveZoneThresholds
            .firstIndex { reserveFraction < $0 }
            ?? configuration.heartRateZoneWeights.index(before: configuration.heartRateZoneWeights.endIndex)
        return configuration.heartRateZoneWeights[index]
    }
}
