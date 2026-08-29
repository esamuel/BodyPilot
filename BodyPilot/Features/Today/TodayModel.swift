import Foundation
import Observation

/// Orchestrates the Today screen: runs the shared readiness pipeline and
/// exposes UI state. No scoring or HealthKit logic lives here.
@MainActor
@Observable
final class TodayModel {
    enum State {
        case loading
        case ready(score: BodyScoreResult, recommendation: DailyRecommendation)
        case failed(String)
    }

    private(set) var state: State = .loading
    /// Body Insights derived from the same readiness pass; empty until ready.
    private(set) var insights: [InsightSnapshot] = []
    /// Recent workout history backing the Workout Journey page.
    private(set) var recentWorkouts: [WorkoutSummary] = []

    private let readiness: ReadinessService
    private let workoutGenerator: WorkoutGenerator
    private let insightEngine: InsightEngine
    private var preferences: ReadinessPreferences = .default

    init(
        healthMetrics: any HealthMetricsProviding = HealthKitClient(),
        workoutGenerator: WorkoutGenerator = WorkoutGenerator(),
        insightEngine: InsightEngine = InsightEngine()
    ) {
        self.readiness = ReadinessService(healthMetrics: healthMetrics)
        self.workoutGenerator = workoutGenerator
        self.insightEngine = insightEngine
    }

    func refresh(checkIn: CheckIn?, profile: UserProfile?, now: Date = .now) async {
        preferences = ReadinessPreferences(profile: profile)
        do {
            let snapshot = try await readiness.snapshot(
                preferences: preferences,
                feeling: checkIn?.feeling,
                soreness: checkIn?.soreness ?? [],
                now: now
            )
            state = .ready(score: snapshot.score, recommendation: snapshot.recommendation)
            recentWorkouts = snapshot.workoutHistory
            insights = insightEngine.insights(
                for: InsightInput(
                    snapshots: snapshot.history,
                    workouts: snapshot.workoutHistory,
                    score: snapshot.score,
                    deltas: snapshot.deltas,
                    recentLoad: snapshot.recentLoad,
                    feeling: checkIn?.feeling,
                    date: now
                )
            )
            WidgetSnapshotStore().publish(
                score: snapshot.score,
                recommendation: snapshot.recommendation,
                insights: insights
            )
            WatchProfileSyncService.shared.publish(
                score: snapshot.score,
                recommendation: snapshot.recommendation
            )
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Generates a validated workout from the current recommendation;
    /// nil while the score isn't ready or when no safe workout fits the time.
    func makeWorkout(timeLimitMinutes: Int? = nil) -> PlannedWorkout? {
        guard case .ready(_, let recommendation) = state else { return nil }
        return try? workoutGenerator.generateWorkout(
            for: WorkoutRequest(
                recommendation: recommendation,
                goal: preferences.goal,
                equipment: preferences.equipment,
                timeLimitMinutes: timeLimitMinutes
            )
        )
    }

    /// Generates a validated workout for an insight CTA. The action only supplies
    /// parameters — the generator still enforces every readiness and safety constraint.
    func makeWorkout(for action: SuggestedAction) -> PlannedWorkout? {
        guard case .ready(_, let recommendation) = state else { return nil }
        var activities = recommendation.preferredActivities
        if let activity = action.activity {
            activities = [activity]
        }
        let adjusted = DailyRecommendation(
            level: recommendation.level,
            recommendedDuration: recommendation.recommendedDuration,
            preferredActivities: activities,
            intensity: recommendation.intensity,
            constraints: recommendation.constraints,
            rationaleFacts: recommendation.rationaleFacts
        )
        return try? workoutGenerator.generateWorkout(
            for: WorkoutRequest(
                recommendation: adjusted,
                goal: preferences.goal,
                equipment: preferences.equipment,
                timeLimitMinutes: action.timeLimitMinutes
            )
        )
    }
}
