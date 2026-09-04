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
actor HealthKitClient: HealthDataProviding, HealthMetricsProviding, SleepDataProviding {
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
        async let distance = dailyStatistics(
            .distanceWalkingRunning, options: .cumulativeSum,
            unit: .meter(), from: start, to: endDate
        )
        async let vo2Max = dailyStatistics(
            .vo2Max, options: .discreteAverage,
            unit: HKUnit(from: "ml/kg*min"), from: start, to: endDate
        )

        let sleepByDay = try await sleep
        let hrvByDay = try await hrv
        let restingHRByDay = try await restingHR
        let stepsByDay = try await steps
        let energyByDay = try await energy
        let exerciseByDay = try await exercise
        let distanceByDay = try await distance
        let vo2MaxByDay = try await vo2Max

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
                    exerciseMinutes: exerciseByDay[day],
                    walkingRunningDistanceMeters: distanceByDay[day],
                    vo2Max: vo2MaxByDay[day]
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
        var summaries: [WorkoutSummary] = []
        summaries.reserveCapacity(workouts.count)

        for workout in workouts {
            summaries.append(
                WorkoutSummary(
                    id: workout.uuid,
                    start: workout.startDate,
                    durationMinutes: workout.duration / 60,
                    activity: ActivityType(workoutActivityType: workout.workoutActivityType),
                    totalEnergyKilocalories: workout
                        .statistics(for: HKQuantityType(.activeEnergyBurned))?
                        .sumQuantity()?
                        .doubleValue(for: .kilocalorie()),
                    heartRateSamples: try await heartRateSamples(for: workout)
                )
            )
        }
        return summaries
    }

    func sleepNights(from startDate: Date, to endDate: Date) async throws -> [SleepNight] {
        let start = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)
        let end = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDate
        let queryStart = calendar.date(byAdding: .hour, value: -18, to: start) ?? start
        let predicate = HKQuery.predicateForSamples(withStart: queryStart, end: end, options: [])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: store)

        struct Candidate {
            let source: String
            let segment: SleepSegment
        }

        let candidates: [Candidate] = samples.compactMap { sample in
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value),
                  let stage = SleepStage(healthKitValue: value) else { return nil }
            return Candidate(
                source: sample.sourceRevision.source.bundleIdentifier,
                segment: SleepSegment(id: sample.uuid, start: sample.startDate, end: sample.endDate, stage: stage)
            )
        }

        let byWakeDay = Dictionary(grouping: candidates) {
            calendar.startOfDay(for: $0.segment.end)
        }

        return byWakeDay.compactMap { day, dayCandidates in
            guard day >= start && day <= endDay else { return nil }
            // Sleep can be recorded by both a Watch and the phone. Use the source
            // with the richest asleep timeline to avoid double-counting overlaps.
            let bySource = Dictionary(grouping: dayCandidates, by: \.source)
            guard let best = bySource.values.max(by: { lhs, rhs in
                asleepCoverage(lhs.map(\.segment)) < asleepCoverage(rhs.map(\.segment))
            }) else { return nil }
            let segments = best.map(\.segment).sorted { $0.start < $1.start }
            guard segments.contains(where: { $0.stage.isAsleep }) else { return nil }
            return SleepNight(date: day, segments: segments)
        }
        .sorted { $0.date < $1.date }
    }

    // MARK: - Private queries

    private func heartRateSamples(for workout: HKWorkout) async throws -> [WorkoutHeartRateSample] {
        let type = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForObjects(from: workout)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: store)
        let unit = HKUnit.count().unitDivided(by: .minute())

        return samples.enumerated().compactMap { index, sample in
            let nextStart = samples.indices.contains(index + 1)
                ? samples[index + 1].startDate
                : workout.endDate
            let end = min(max(sample.endDate, nextStart), workout.endDate)
            guard end > sample.startDate else { return nil }
            return WorkoutHeartRateSample(
                start: sample.startDate,
                end: end,
                beatsPerMinute: sample.quantity.doubleValue(for: unit)
            )
        }
    }

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
        let nights = try await sleepNights(from: start, to: end)
        return Dictionary(uniqueKeysWithValues: nights.map { ($0.date, $0.totalSleep / 3600) })
    }

    private func asleepCoverage(_ segments: [SleepSegment]) -> TimeInterval {
        segments.lazy.filter { $0.stage.isAsleep }.reduce(0) { $0 + $1.duration }
    }
}

private extension SleepStage {
    nonisolated init?(healthKitValue: HKCategoryValueSleepAnalysis) {
        switch healthKitValue {
        case .awake: self = .awake
        case .asleepREM: self = .rem
        case .asleepCore: self = .core
        case .asleepDeep: self = .deep
        case .asleep, .asleepUnspecified: self = .asleepUnspecified
        case .inBed: return nil
        @unknown default: return nil
        }
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
