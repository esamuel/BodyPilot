import Foundation

/// Abstraction over HealthKit access. Views and engines never talk to HealthKit directly.
protocol HealthDataProviding: Sendable {
    var isHealthDataAvailable: Bool { get }
    /// True when the system would show the permission sheet for our required types.
    func authorizationRequestNeeded() async throws -> Bool
    func requestAuthorization() async throws
}

/// Provides normalized daily health metrics and workout history.
/// Implementations return domain models only — raw HealthKit samples never cross this boundary.
protocol HealthMetricsProviding: Sendable {
    func dailySnapshots(from startDate: Date, to endDate: Date) async throws -> [DailyHealthSnapshot]
    func workouts(from startDate: Date, to endDate: Date) async throws -> [WorkoutSummary]
}

/// Provides normalized sleep sessions. HealthKit samples are converted into
/// product models before they leave the health-data boundary.
protocol SleepDataProviding: Sendable {
    func sleepNights(from startDate: Date, to endDate: Date) async throws -> [SleepNight]
}

/// Derived, privacy-preserving context handed to the AI coach.
/// Never contains raw HealthKit samples — only deltas relative to the personal baseline.
struct AIContext: Codable, Hashable, Sendable {
    let bodyScore: Int
    let confidence: Double
    /// Sleep relative to baseline, e.g. -0.08 for 8% below normal; nil when unknown.
    let sleepDelta: Double?
    /// HRV relative to baseline; nil when unknown.
    let hrvDelta: Double?
    /// Resting heart rate delta from baseline in BPM; nil when unknown.
    let restingHRDeltaBPM: Int?
    let recentLoad: TrainingLoad
    let feeling: FeelingLevel
    let goal: FitnessGoal
    let equipment: [EquipmentType]
    let preferredActivities: [ActivityType]
    let preferredWorkoutMinutes: Int

    init(
        bodyScore: Int,
        confidence: Double,
        sleepDelta: Double?,
        hrvDelta: Double?,
        restingHRDeltaBPM: Int?,
        recentLoad: TrainingLoad,
        feeling: FeelingLevel,
        goal: FitnessGoal,
        equipment: [EquipmentType],
        preferredActivities: [ActivityType] = [.walking],
        preferredWorkoutMinutes: Int = 30
    ) {
        self.bodyScore = bodyScore
        self.confidence = confidence
        self.sleepDelta = sleepDelta
        self.hrvDelta = hrvDelta
        self.restingHRDeltaBPM = restingHRDeltaBPM
        self.recentLoad = recentLoad
        self.feeling = feeling
        self.goal = goal
        self.equipment = equipment
        self.preferredActivities = preferredActivities
        self.preferredWorkoutMinutes = preferredWorkoutMinutes
    }
}

/// A single request to the coach, always carrying deterministic constraints.
struct CoachRequest: Sendable {
    let message: String
    let context: AIContext
    let constraints: [WorkoutConstraint]
    let profile: CoachProfile
}

struct CoachResponse: Sendable {
    enum Source: Sendable, Equatable {
        case onDeviceAI
        case fallback
        case safety
    }

    let text: String
    let source: Source
    let fallbackReason: String?

    init(text: String, source: Source, fallbackReason: String? = nil) {
        self.text = text
        self.source = source
        self.fallbackReason = fallbackReason
    }
}

/// Abstraction over the language-model provider (Foundation Models in production).
/// Implementations must be replaceable and must have a non-AI fallback.
protocol CoachProviding: Sendable {
    func respond(to request: CoachRequest) async throws -> CoachResponse
}
