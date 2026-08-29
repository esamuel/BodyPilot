import Foundation
import HealthKit

enum HealthKitClientError: LocalizedError {
    case healthDataUnavailable

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            String(localized: "Health data is not available on this device.")
        }
    }
}

/// The only type that talks to HealthKit directly. Converts raw samples into
/// normalized domain models; raw HealthKit data never crosses this boundary.
actor HealthKitClient: HealthDataProviding, HealthMetricsProviding {
    private let store = HKHealthStore()
    private let calendar = Calendar.current

    nonisolated var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func authorizationRequestNeeded() async throws -> Bool {
        let status = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKAuthorizationRequestStatus, Error>) in
            store.getRequestStatusForAuthorization(
                toShare: HealthPermissions.writeTypes,
                read: HealthPermissions.readTypes
            ) { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
        return status == .shouldRequest
    }

    func requestAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw HealthKitClientError.healthDataUnavailable
        }
        try await store.requestAuthorization(
            toShare: HealthPermissions.writeTypes,
            read: HealthPermissions.readTypes
        )
    }

    // MARK: - HealthMetricsProviding

    func dailySnapshots(from startDate: Date, to endDate: Date) async throws -> [DailyHealthSnapshot] {
        let start = calendar.startOfDay(for: startDate)

        async let sleep = sleepHoursByDay(from: start, to: endDate)
        async let hrv = dailyStatistics(
            .heartRateVariabilitySDNN, options: .discreteAverage,
            unit: .secondUnit(with: .milli), from: start, to: endDate
        )
        async let restingHR = dailyStatistics(
            .restingHeartRate, options: .discreteAverage,
            unit: HKUnit.count().unitDivided(by: .minute()), from: start, to: endDate
        )
        async let steps = dailyStatistics(
            .stepCount, options: .cumulativeSum,
            unit: .count(), from: start, to: endDate
        )
        async let energy = dailyStatistics(
            .activeEnergyBurned, options: .cumulativeSum,
            unit: .kilocalorie(), from: start, to: endDate
        )
        async let exercise = dailyStatistics(
            .appleExerciseTime, options: .cumulativeSum,
            unit: .minute(), from: start, to: endDate
        )

        let sleepByDay = try await sleep
        let hrvByDay = try await hrv
        let restingHRByDay = try await restingHR
        let stepsByDay = try await steps
        let energyByDay = try await energy
        let exerciseByDay = try await exercise

        var snapshots: [DailyHealthSnapshot] = []
        var day = start
        while day <= endDate {
            snapshots.append(
                DailyHealthSnapshot(
                    date: day,
                    sleepHours: sleepByDay[day],
                    hrvSDNN: hrvByDay[day],
                    restingHeartRate: restingHRByDay[day],
                    steps: stepsByDay[day],
                    activeEnergyKilocalories: energyByDay[day],
                    exerciseMinutes: exerciseByDay[day]
                )
            )
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return snapshots
    }

    func workouts(from startDate: Date, to endDate: Date) async throws -> [WorkoutSummary] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let workouts = try await descriptor.result(for: store)
        return workouts.map { workout in
            WorkoutSummary(
                start: workout.startDate,
                durationMinutes: workout.duration / 60,
                activity: ActivityType(workoutActivityType: workout.workoutActivityType),
                totalEnergyKilocalories: workout
                    .statistics(for: HKQuantityType(.activeEnergyBurned))?
                    .sumQuantity()?
                    .doubleValue(for: .kilocalorie())
            )
        }
    }

    // MARK: - Private queries

    private func dailyStatistics(
        _ identifier: HKQuantityTypeIdentifier,
        options: HKStatisticsOptions,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async throws -> [Date: Double] {
        let type = HKQuantityType(identifier)
        let datePredicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: datePredicate),
            options: options,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await descriptor.result(for: store)

        var values: [Date: Double] = [:]
        for statistics in collection.statistics() {
            let quantity = options.contains(.cumulativeSum)
                ? statistics.sumQuantity()
                : statistics.averageQuantity()
            if let quantity {
                values[statistics.startDate] = quantity.doubleValue(for: unit)
            }
        }
        return values
    }

    private func sleepHoursByDay(from start: Date, to end: Date) async throws -> [Date: Double] {
        // Include the prior evening so sleep starting before midnight counts toward the wake day.
        let queryStart = calendar.date(byAdding: .hour, value: -12, to: start) ?? start
        let predicate = HKQuery.predicateForSamples(withStart: queryStart, end: end, options: [])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: store)

        let asleepValues = HKCategoryValueSleepAnalysis.allAsleepValues
        var hours: [Date: Double] = [:]
        for sample in samples {
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value),
                  asleepValues.contains(value) else { continue }
            // Attribute each asleep interval to the day the user woke up.
            // V1 limitation: overlapping samples from multiple sources may double-count.
            let day = calendar.startOfDay(for: sample.endDate)
            hours[day, default: 0] += sample.endDate.timeIntervalSince(sample.startDate) / 3600
        }
        return hours
    }
}

extension ActivityType {
    /// HealthKit activity used when the app starts or saves a workout.
    nonisolated var workoutActivityType: HKWorkoutActivityType {
        switch self {
        case .walking: .walking
        case .running: .running
        case .cycling: .cycling
        case .strength: .traditionalStrengthTraining
        case .mobility: .flexibility
        case .balance: .mindAndBody
        case .stretching: .flexibility
        case .chairExercise: .other
        case .swimming: .swimming
        case .core: .coreTraining
        case .recovery: .preparationAndRecovery
        }
    }

    /// Default session location for live workout configuration.
    nonisolated var defaultLocationType: HKWorkoutSessionLocationType {
        switch self {
        case .walking, .running, .cycling: .outdoor
        default: .indoor
        }
    }

    /// Maps a HealthKit workout activity to the product's activity set; nil when unsupported.
    nonisolated init?(workoutActivityType: HKWorkoutActivityType) {
        switch workoutActivityType {
        case .walking, .hiking: self = .walking
        case .running: self = .running
        case .cycling: self = .cycling
        case .traditionalStrengthTraining, .functionalStrengthTraining: self = .strength
        case .flexibility: self = .stretching
        case .yoga, .pilates: self = .mobility
        case .coreTraining: self = .core
        case .swimming: self = .swimming
        case .mindAndBody: self = .recovery
        default: return nil
        }
    }
}
