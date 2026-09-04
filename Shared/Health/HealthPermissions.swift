import HealthKit

/// Central definition of every HealthKit type the app requests.
/// Request only what enabled features need (PRD section 8).
/// Nonisolated so the HealthKitClient actor can read these off the main actor.
nonisolated enum HealthPermissions {
    /// Read access: signals feeding the Body Score, baselines, and progress.
    static var readTypes: Set<HKObjectType> {
        [
            HKObjectType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.vo2Max),
            HKCategoryType(.sleepAnalysis),
        ]
    }

    /// Write access: only workouts the app itself creates.
    static var writeTypes: Set<HKSampleType> {
        [
            HKObjectType.workoutType(),
        ]
    }
}
