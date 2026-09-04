import Foundation

/// One day of normalized health signals. Nil fields mean the data was missing,
/// which reduces downstream confidence but never fails a calculation.
struct DailyHealthSnapshot: Codable, Hashable, Sendable {
    /// Start of the day this snapshot describes.
    let date: Date
    let sleepHours: Double?
    /// Heart-rate variability (SDNN) in milliseconds.
    let hrvSDNN: Double?
    /// Resting heart rate in beats per minute.
    let restingHeartRate: Double?
    let steps: Double?
    let activeEnergyKilocalories: Double?
    let exerciseMinutes: Double?
    let walkingRunningDistanceMeters: Double?
    /// Maximal oxygen consumption in milliliters per kilogram per minute.
    let vo2Max: Double?

    nonisolated init(
        date: Date,
        sleepHours: Double?,
        hrvSDNN: Double?,
        restingHeartRate: Double?,
        steps: Double?,
        activeEnergyKilocalories: Double?,
        exerciseMinutes: Double?,
        walkingRunningDistanceMeters: Double? = nil,
        vo2Max: Double? = nil
    ) {
        self.date = date
        self.sleepHours = sleepHours
        self.hrvSDNN = hrvSDNN
        self.restingHeartRate = restingHeartRate
        self.steps = steps
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.exerciseMinutes = exerciseMinutes
        self.walkingRunningDistanceMeters = walkingRunningDistanceMeters
        self.vo2Max = vo2Max
    }
}

/// A heart-rate reading normalized at the HealthKit boundary.
struct WorkoutHeartRateSample: Codable, Hashable, Sendable {
    let start: Date
    let end: Date
    let beatsPerMinute: Double

    nonisolated init(start: Date, end: Date, beatsPerMinute: Double) {
        self.start = start
        self.end = end
        self.beatsPerMinute = beatsPerMinute
    }

    nonisolated var durationMinutes: Double {
        max(end.timeIntervalSince(start) / 60, 0)
    }
}

/// A completed workout, normalized from HealthKit or created by the app.
struct WorkoutSummary: Codable, Hashable, Identifiable, Sendable {
    /// Stable HealthKit UUID when available. Synthetic providers supply a stable fixture UUID.
    let id: UUID
    let start: Date
    let durationMinutes: Double
    /// Mapped product activity; nil when the source activity has no product equivalent.
    let activity: ActivityType?
    let totalEnergyKilocalories: Double?
    /// Samples are kept only in memory long enough to derive load.
    let heartRateSamples: [WorkoutHeartRateSample]
    /// App-owned journal override. HealthKit-only workouts usually have no value.
    let perceivedExertion: Int?

    nonisolated init(
        id: UUID = UUID(),
        start: Date,
        durationMinutes: Double,
        activity: ActivityType?,
        totalEnergyKilocalories: Double?,
        heartRateSamples: [WorkoutHeartRateSample] = [],
        perceivedExertion: Int? = nil
    ) {
        self.id = id
        self.start = start
        self.durationMinutes = durationMinutes
        self.activity = activity
        self.totalEnergyKilocalories = totalEnergyKilocalories
        self.heartRateSamples = heartRateSamples
        self.perceivedExertion = perceivedExertion
    }
}

/// A single dated metric value used for baseline calculations.
struct DatedValue: Hashable, Sendable {
    let date: Date
    let value: Double
}
