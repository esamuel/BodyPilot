import Foundation

/// A single human-readable fact used to explain a score or recommendation.
struct ExplanationFact: Codable, Hashable, Sendable {
    let title: String
    let detail: String
}

/// The signal categories that contribute to the Body Score.
enum ScoreComponentKind: String, Codable, CaseIterable, Sendable {
    case sleep
    case hrv
    case restingHeartRate
    case recentLoad
    case recoveryHistory
    case subjectiveFeeling
}

/// Centralized Body Score weighting. The single place to tune weights; they must sum to 1.0.
struct BodyScoreWeights: Sendable {
    let sleep: Double
    let hrv: Double
    let restingHeartRate: Double
    let recentLoad: Double
    let recoveryHistory: Double
    let subjectiveFeeling: Double

    /// Initial product weighting per PRD section 7.3.
    static let `default` = BodyScoreWeights(
        sleep: 0.25,
        hrv: 0.20,
        restingHeartRate: 0.15,
        recentLoad: 0.20,
        recoveryHistory: 0.10,
        subjectiveFeeling: 0.10
    )

    var total: Double {
        sleep + hrv + restingHeartRate + recentLoad + recoveryHistory + subjectiveFeeling
    }

    func weight(for kind: ScoreComponentKind) -> Double {
        switch kind {
        case .sleep: sleep
        case .hrv: hrv
        case .restingHeartRate: restingHeartRate
        case .recentLoad: recentLoad
        case .recoveryHistory: recoveryHistory
        case .subjectiveFeeling: subjectiveFeeling
        }
    }
}

/// One weighted contribution to the Body Score.
struct ScoreComponent: Codable, Hashable, Sendable {
    let kind: ScoreComponentKind
    let weight: Double
    /// Normalized 0–1 value relative to the personal baseline; nil when data is missing.
    let normalizedValue: Double?
}

/// Deterministic output of the Body Score engine.
struct BodyScoreResult: Sendable {
    let score: Int
    let confidence: Double
    let readiness: ReadinessLevel
    let components: [ScoreComponent]
    let explanationFacts: [ExplanationFact]
    let computedAt: Date
}

/// An inclusive workout duration window in minutes.
struct DurationRange: Codable, Hashable, Sendable {
    let minMinutes: Int
    let maxMinutes: Int
}

/// Hard constraints the workout generator must respect. AI may never override these.
enum WorkoutConstraint: Codable, Hashable, Sendable {
    case maxDuration(minutes: Int)
    case avoidHighIntensity
    case avoidSorenessArea(SorenessArea)
    case equipmentLimit([EquipmentType])
}

/// Deterministic output of the recommendation engine.
struct DailyRecommendation: Sendable {
    let level: ReadinessLevel
    let recommendedDuration: DurationRange
    let preferredActivities: [ActivityType]
    let intensity: WorkoutIntensity
    let constraints: [WorkoutConstraint]
    let rationaleFacts: [ExplanationFact]

    var dailySuggestion: DailySuggestion {
        switch intensity {
        case .recovery:
            level == .recover ? .rest : .activeRecovery
        case .light:
            .light
        case .moderate:
            .moderate
        case .hard:
            .hard
        }
    }
}
