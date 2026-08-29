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
}

/// A completed workout, normalized from HealthKit or created by the app.
struct WorkoutSummary: Codable, Hashable, Sendable {
    let start: Date
    let durationMinutes: Double
    /// Mapped product activity; nil when the source activity has no product equivalent.
    let activity: ActivityType?
    let totalEnergyKilocalories: Double?
}

/// A single dated metric value used for baseline calculations.
struct DatedValue: Hashable, Sendable {
    let date: Date
    let value: Double
}
