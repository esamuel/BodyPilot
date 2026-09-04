import Foundation

struct CorridorConfiguration: Sendable {
    let baselineDays: Int
    let minimumBaselineDays: Int
    let minimumTargetLoad: Double
    let lowerTargetFraction: Double
    let upperTargetFraction: Double
    let minimumRecoveryFactor: Double
    let maximumRecoveryFactor: Double
    let prescribedRestFactor: Double

    static let `default` = CorridorConfiguration(
        baselineDays: 28,
        minimumBaselineDays: 7,
        minimumTargetLoad: 100,
        lowerTargetFraction: 0.65,
        upperTargetFraction: 1.35,
        minimumRecoveryFactor: 0.55,
        maximumRecoveryFactor: 1.2,
        prescribedRestFactor: 0.65
    )
}

/// Produces a personal daily healthy-load band from prior load and recovery signals.
struct CorridorEngine: Sendable {
    let configuration: CorridorConfiguration
    let loadEngine: LoadEngine
    let baselineEngine: BaselineEngine
    let calendar: Calendar

    init(
        configuration: CorridorConfiguration = .default,
        loadEngine: LoadEngine = LoadEngine(),
        baselineEngine: BaselineEngine = BaselineEngine(),
        calendar: Calendar = .current
    ) {
        self.configuration = configuration
        self.loadEngine = loadEngine
        self.baselineEngine = baselineEngine
        self.calendar = calendar
    }

    func corridor(
        window: CorridorWindow,
        snapshots: [DailyHealthSnapshot],
        workouts: [WorkoutSummary],
        lifeStatuses: [LifeStatus] = [],
        asOf date: Date
    ) -> ActivityCorridor {
        let today = calendar.startOfDay(for: date)
        let restingHeartRate = restingBaseline(in: snapshots, asOf: date)
        let estimatedMaximum = estimatedMaximumHeartRate(in: workouts)

        let allDailyLoads = dailyLoads(
            workouts: workouts,
            through: today,
            restingHeartRate: restingHeartRate,
            maximumHeartRate: estimatedMaximum
        )

        let days = (0..<window.rawValue).reversed().compactMap { offset -> CorridorDay? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return corridorDay(
                for: day,
                snapshots: snapshots,
                dailyLoads: allDailyLoads
            )
        }

        let baselineCount = max(allDailyLoads.count - window.rawValue, 0)
        let confidence = min(
            Double(baselineCount) / Double(configuration.minimumBaselineDays),
            1
        )
        return ActivityCorridor(
            days: days,
            confidence: confidence,
            isPaused: LifeStatusResolver.activeStatus(
                in: lifeStatuses,
                at: date,
                calendar: calendar
            ) != nil
        )
    }

    private func corridorDay(
        for day: Date,
        snapshots: [DailyHealthSnapshot],
        dailyLoads: [Date: Double]
    ) -> CorridorDay {
        let historical = (1...configuration.baselineDays).compactMap { offset -> Double? in
            guard let historicalDay = calendar.date(byAdding: .day, value: -offset, to: day) else {
                return nil
            }
            return dailyLoads[historicalDay]
        }
        let typicalLoad = max(
            historical.isEmpty ? 0 : historical.reduce(0, +) / Double(historical.count),
            configuration.minimumTargetLoad
        )
        let recoveryFactor = recoveryAdjustment(snapshots: snapshots, asOf: day)
        let isRestRecommended = recoveryFactor <= configuration.prescribedRestFactor
        let lowerBound = isRestRecommended
            ? 0
            : typicalLoad * configuration.lowerTargetFraction * recoveryFactor
        let upperBound = typicalLoad * configuration.upperTargetFraction * recoveryFactor
        let load = dailyLoads[day] ?? 0
        let state: CorridorState = if load < lowerBound {
            .below
        } else if load > upperBound {
            .above
        } else {
            .inside
        }

        return CorridorDay(
            date: day,
            lowerBound: lowerBound,
            upperBound: upperBound,
            load: load,
            state: state,
            isRestRecommended: isRestRecommended
        )
    }

    private func dailyLoads(
        workouts: [WorkoutSummary],
        through date: Date,
        restingHeartRate: Double?,
        maximumHeartRate: Double?
    ) -> [Date: Double] {
        let count = configuration.baselineDays + CorridorWindow.thirtyDays.rawValue
        return (0..<count).reduce(into: [:]) { result, offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: date) else { return }
            result[day] = loadEngine.dailyLoad(
                workouts: workouts,
                on: day,
                restingHeartRate: restingHeartRate,
                maximumHeartRate: maximumHeartRate
            )
        }
    }

    private func restingBaseline(
        in snapshots: [DailyHealthSnapshot],
        asOf date: Date
    ) -> Double? {
        let values = snapshots.compactMap { snapshot in
            snapshot.restingHeartRate.map { DatedValue(date: snapshot.date, value: $0) }
        }
        return baselineEngine.baseline(for: values, window: .primary, asOf: date)?.mean
    }

    private func estimatedMaximumHeartRate(in workouts: [WorkoutSummary]) -> Double? {
        workouts
            .flatMap(\.heartRateSamples)
            .map(\.beatsPerMinute)
            .max()
            .map { max($0 * loadEngine.configuration.observedPeakReserve,
                       loadEngine.configuration.minimumEstimatedMaxHeartRate) }
    }

    private func recoveryAdjustment(
        snapshots: [DailyHealthSnapshot],
        asOf date: Date
    ) -> Double {
        let deltas = baselineEngine.deltas(for: snapshots, asOf: date)
        let sleepContribution = (deltas.sleepDelta ?? 0) * 0.35
        let hrvContribution = (deltas.hrvDelta ?? 0) * 0.30
        let restingContribution = -((deltas.restingHRDeltaBPM ?? 0) / 20) * 0.35
        return min(
            max(
                1 + sleepContribution + hrvContribution + restingContribution,
                configuration.minimumRecoveryFactor
            ),
            configuration.maximumRecoveryFactor
        )
    }
}
