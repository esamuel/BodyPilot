import Foundation

/// Readiness band derived from the Body Score (0–100).
/// Bands per PRD: 80–100 Strong, 65–79 Ready, 45–64 Easy, 0–44 Recover.
enum ReadinessLevel: String, Codable, CaseIterable, Sendable {
    case strong
    case ready
    case easy
    case recover

    /// Maps a Body Score to its readiness band. Out-of-range input clamps to the nearest band.
    init(bodyScore: Int) {
        switch bodyScore {
        case 80...: self = .strong
        case 65...79: self = .ready
        case 45...64: self = .easy
        default: self = .recover
        }
    }
}

/// The user's primary goal, chosen during onboarding.
enum FitnessGoal: String, Codable, CaseIterable, Sendable {
    case getActiveAgain
    case loseWeight
    case walkingEndurance
    case buildStrength
    case improveMobility
    case improveBalance
    case healthyAging
    case generalFitness
}

/// Premium rebuild onboarding goals. Multiple selections are allowed and are
/// mapped into the existing readiness/workout preference model.
enum OnboardingGoal: String, Codable, CaseIterable, Sendable {
    case walkMore
    case sleepBetter
    case buildConsistency
    case recoverSmarter
}

/// Self-reported current activity level, chosen during onboarding.
enum ActivityFrequency: String, Codable, CaseIterable, Sendable {
    case beginner
    case occasional
    case regular
    case veryActive
}

/// Activity categories supported by the product (V1 set per PRD).
enum ActivityType: String, Codable, CaseIterable, Sendable {
    case walking
    case running
    case cycling
    case strength
    case mobility
    case balance
    case stretching
    case chairExercise
    case swimming
    case core
    case recovery
}

/// Equipment the user has access to.
enum EquipmentType: String, Codable, CaseIterable, Sendable {
    case none
    case resistanceBands
    case dumbbells
    case homeGym
    case fullGym
}

/// Target intensity of a generated workout.
enum WorkoutIntensity: String, Codable, CaseIterable, Sendable {
    case recovery
    case light
    case moderate
    case hard

    /// Ordering for cap and never-exceed comparisons (recovery < light < moderate < hard).
    var rank: Int {
        switch self {
        case .recovery: 0
        case .light: 1
        case .moderate: 2
        case .hard: 3
        }
    }
}

/// One-tap readiness answer from the daily check-in.
enum FeelingLevel: String, Codable, CaseIterable, Sendable {
    case veryTired
    case tired
    case normal
    case good
    case excellent
}

/// Optional soreness areas from the daily check-in.
enum SorenessArea: String, Codable, CaseIterable, Sendable {
    case legs
    case back
    case knee
    case shoulder
    case general
}

/// Coarse recent training load classification.
/// `rest` (not `none`) so switches over `TrainingLoad?` stay unambiguous.
enum TrainingLoad: String, Codable, CaseIterable, Sendable {
    case rest
    case light
    case moderate
    case heavy
}

/// Coaching tone preference, chosen during onboarding.
enum CoachTone: String, Codable, CaseIterable, Sendable {
    case supportive
    case direct
    case energetic
}
