import Foundation
import Observation

struct PathVitals: Sendable, Equatable {
    let sleepHours: Double?
    let restingHeartRate: Double?
    let hrvSDNN: Double?
    let steps: Double?
}

@MainActor
@Observable
final class PathModel {
    private(set) var corridor: ActivityCorridor?
    private(set) var streak = StreakResult(count: 0, isFrozen: false, consecutiveAboveDays: 0)
    private(set) var recommendation: DailyRecommendation?
    private(set) var vitals = PathVitals(
        sleepHours: nil,
        restingHeartRate: nil,
        hrvSDNN: nil,
        steps: nil
    )
    private(set) var insights: [InsightSnapshot] = []
    private(set) var recentWorkouts: [WorkoutSummary] = []
    private(set) var recaps: [RecapSummary] = []
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    let requiresHealthAccess: Bool

    private let readiness: ReadinessService
    private let workoutGenerator: WorkoutGenerator
    private let insightEngine: InsightEngine
    private let recapEngine: RecapEngine
    private var preferences: ReadinessPreferences = .default

    init(
        healthMetrics: any HealthMetricsProviding = HealthKitClient(),
        requiresHealthAccess: Bool = true,
        workoutGenerator: WorkoutGenerator = WorkoutGenerator(),
        insightEngine: InsightEngine = InsightEngine(),
        recapEngine: RecapEngine = RecapEngine()
    ) {
        self.requiresHealthAccess = requiresHealthAccess
        readiness = ReadinessService(healthMetrics: healthMetrics)
        self.workoutGenerator = workoutGenerator
        self.insightEngine = insightEngine
        self.recapEngine = recapEngine
    }

    func refresh(
        checkIn: CheckIn?,
        profile: UserProfile?,
        lifeStatuses: [LifeStatus],
        journalEntries: [WorkoutJournalEntry] = [],
        now: Date = .now
    ) async {
        isLoading = true
        errorMessage = nil
        preferences = ReadinessPreferences(profile: profile)

        do {
            let snapshot = try await readiness.snapshot(
                preferences: preferences,
                feeling: checkIn?.feeling,
                soreness: checkIn?.soreness ?? [],
                lifeStatuses: lifeStatuses,
                workoutRPEOverrides: Dictionary(
                    uniqueKeysWithValues: journalEntries.compactMap { entry in
                        entry.perceivedExertion.map { (entry.workoutID, $0) }
                    }
                ),
                now: now
            )
            corridor = snapshot.corridor
            streak = snapshot.streak
            recommendation = snapshot.recommendation
            recentWorkouts = snapshot.workoutHistory

            let today = Calendar.current.startOfDay(for: now)
            let current = snapshot.history.first { $0.date == today }
            vitals = PathVitals(
                sleepHours: current?.sleepHours,
                restingHeartRate: current?.restingHeartRate,
                hrvSDNN: current?.hrvSDNN,
                steps: current?.steps
            )
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
            recaps = recapEngine.summaries(
                snapshots: snapshot.history,
                workouts: snapshot.workoutHistory,
                journalEntries: journalEntries,
                asOf: now
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
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func corridor(for window: CorridorWindow) -> ActivityCorridor? {
        guard let corridor else { return nil }
        return ActivityCorridor(
            days: Array(corridor.days.suffix(window.rawValue)),
            confidence: corridor.confidence,
            isPaused: corridor.isPaused
        )
    }

    func makeWorkout(timeLimitMinutes: Int? = nil) -> PlannedWorkout? {
        guard let recommendation else { return nil }
        return try? workoutGenerator.generateWorkout(
            for: WorkoutRequest(
                recommendation: recommendation,
                goal: preferences.goal,
                equipment: preferences.equipment,
                timeLimitMinutes: timeLimitMinutes
            )
        )
    }

    func makeWorkout(for action: SuggestedAction) -> PlannedWorkout? {
        guard let recommendation else { return nil }
        let activities = action.activity.map { [$0] } ?? recommendation.preferredActivities
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
