import Foundation

/// The Body Insight "worlds". V1 builds sleep, movement, recovery, trainingLoad,
/// and workoutHistory; the remaining kinds ship in V1.1 per BODY_INSIGHTS_EXPERIENCE.md.
enum InsightKind: String, Codable, CaseIterable, Sendable {
    case sleep
    case movement
    case recovery
    case heart
    case trainingLoad
    case strength
    case mobilityBalance
    case workoutHistory
}

/// Calm, non-judgmental status classification used for tinting and card labels.
/// Meaning is always relative to the user's own baseline, never population cutoffs.
enum InsightStatus: String, Codable, Sendable {
    case excellent
    case good
    case steady
    case low
    case unknown
}

/// Direction of a metric relative to the personal baseline or recent window.
enum TrendDirection: String, Codable, Sendable {
    case up
    case down
    case steady
    case unknown
}

/// Today vs the user's own normal for one supporting metric.
struct BaselineComparison: Hashable, Sendable {
    let label: String
    let todayText: String
    let typicalText: String
    let sevenDayTrend: TrendDirection
}

/// A deterministic, generator-validated action. The UI feeds these parameters
/// into WorkoutGenerator — an insight can suggest, never bypass, validation.
struct SuggestedAction: Hashable, Sendable {
    let title: String
    /// Preferred activity for the generated session; nil keeps the daily recommendation.
    let activity: ActivityType?
    /// Hard time cap in minutes; nil keeps the recommended duration.
    let timeLimitMinutes: Int?
}

/// Deterministic output of the InsightEngine for one world.
/// Everything shown on an insight page derives from this snapshot.
struct InsightSnapshot: Sendable {
    let kind: InsightKind
    let status: InsightStatus
    /// Short status wording for the hero/card, e.g. "Restorative night".
    let statusLabel: String
    /// One dominant value, e.g. "7h 42m" or "6,240 steps".
    let primaryValueText: String
    /// Two–three sentence deterministic explanation ("What it means").
    let summary: String
    /// Key numbers for Section C.
    let facts: [ExplanationFact]
    /// "Your normal" rows for Section D.
    let comparisons: [BaselineComparison]
    let trend: TrendDirection
    /// Daily series for the pattern chart (Section E), oldest first.
    let pattern: [DatedValue]
    let action: SuggestedAction?
    /// 0–1; missing data reduces confidence, never invents a status.
    let confidence: Double
    let generatedAt: Date
}

/// Validated facts handed to the AI for wording only. The AI may rephrase and
/// explain this context; it may never alter values, invent causes, or diagnose.
struct InsightContext: Sendable {
    let kind: InsightKind
    let status: InsightStatus
    let facts: [ExplanationFact]
    let baselineComparisons: [BaselineComparison]
    let safeActions: [String]
    let confidence: Double
}
