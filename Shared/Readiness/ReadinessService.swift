import Foundation

/// One computed readiness snapshot: everything derived from health data at a moment in time.
/// Carries the normalized history it was computed from so downstream consumers
/// (Body Insights) never re-run the same HealthKit queries.
struct ReadinessSnapshot: Sendable {
    let score: BodyScoreResult
    let recommendation: DailyRecommendation
    let deltas: BaselineDeltas
    let recentLoad: TrainingLoad
    let history: [DailyHealthSnapshot]
    let workoutHistory: [WorkoutSummary]
    let corridor: ActivityCorridor
    let streak: StreakResult
}

/// User preferences fed into the pipeline (from the stored profile or defaults).
struct ReadinessPreferences: Sendable {
    let goal: FitnessGoal
    let preferredActivities: [ActivityType]
    let preferredWorkoutMinutes: Int
    let equipment: [EquipmentType]

    static let `default` = ReadinessPreferences(
        goal: .generalFitness,
        preferredActivities: [.walking],
        preferredWorkoutMinutes: 30,
        equipment: [.none]
    )
}

extension ReadinessPreferences {
    /// Builds preferences from the stored profile, falling back to defaults.
    @MainActor
    init(profile: UserProfile?) {
        self.init(
            goal: profile?.goal ?? Self.default.goal,
            preferredActivities: profile?.preferredActivities ?? Self.default.preferredActivities,
            preferredWorkoutMinutes: profile?.preferredWorkoutMinutes ?? Self.default.preferredWorkoutMinutes,
            equipment: profile?.equipment ?? Self.default.equipment
        )
    }
}

enum ReadinessServiceError: LocalizedError {
    case invalidDateRange

    var errorDescription: String? {
        switch self {
        case .invalidDateRange:
            String(localized: "Could not compute the date range.")
        }
    }
}

/// The single pipeline that turns normalized health data into a Body Score and
/// daily recommendation. Today, Coach, the Watch, and App Intents all call this;
/// readiness business logic lives here and in the engines, never in feature code.
struct ReadinessService: Sendable {
    private let healthMetrics: any HealthMetricsProviding
    private let baselineEngine: BaselineEngine
    private let loadEngine: LoadEngine
    private let scoreEngine: BodyScoreEngine
    private let corridorEngine: CorridorEngine
    private let streakEngine: StreakEngine
    private let recommendationEngine: RecommendationEngine

    init(
        healthMetrics: any HealthMetricsProviding = HealthKitClient(),
        baselineEngine: BaselineEngine = BaselineEngine(),
        loadEngine: LoadEngine = LoadEngine(),
        scoreEngine: BodyScoreEngine = BodyScoreEngine(),
        corridorEngine: CorridorEngine = CorridorEngine(),
        streakEngine: StreakEngine = StreakEngine(),
        recommendationEngine: RecommendationEngine = RecommendationEngine()
    ) {
        self.healthMetrics = healthMetrics
        self.baselineEngine = baselineEngine
        self.loadEngine = loadEngine
        self.scoreEngine = scoreEngine
        self.corridorEngine = corridorEngine
        self.streakEngine = streakEngine
        self.recommendationEngine = recommendationEngine
    }

    func snapshot(
        preferences: ReadinessPreferences,
        feeling: FeelingLevel?,
        soreness: [SorenessArea],
        lifeStatuses: [LifeStatus] = [],
        workoutRPEOverrides: [UUID: Int] = [:],
        now: Date = .now
    ) async throws -> ReadinessSnapshot {
        let calendar = Calendar.current
        guard let historyStart = calendar.date(byAdding: .year, value: -6, to: now),
              let workoutStart = calendar.date(byAdding: .year, value: -1, to: now) else {
            throw ReadinessServiceError.invalidDateRange
        }

        async let snapshotsTask = healthMetrics.dailySnapshots(from: historyStart, to: now)
        async let workoutsTask = healthMetrics.workouts(from: workoutStart, to: now)
        let snapshots = try await snapshotsTask
        let rawWorkouts = try await workoutsTask
        let workouts = rawWorkouts.map { workout in
            WorkoutSummary(
                id: workout.id,
                start: workout.start,
                durationMinutes: workout.durationMinutes,
                activity: workout.activity,
                totalEnergyKilocalories: workout.totalEnergyKilocalories,
                heartRateSamples: workout.heartRateSamples,
                perceivedExertion: workoutRPEOverrides[workout.id] ?? workout.perceivedExertion
            )
        }

        let deltas = baselineEngine.deltas(for: snapshots, asOf: now)
        let recentLoad = loadEngine.recentLoad(workouts: workouts, asOf: now)
        let corridor = corridorEngine.corridor(
            window: .thirtyDays,
            snapshots: snapshots,
            workouts: workouts,
            lifeStatuses: lifeStatuses,
            asOf: now
        )
        let streak = streakEngine.streak(
            days: corridor.days,
            lifeStatuses: lifeStatuses,
            asOf: now
        )
        let score = scoreEngine.computeScore(
            from: BodyScoreInput(
                deltas: deltas,
                recentLoad: recentLoad,
                recoveryConsistency: loadEngine.recoveryConsistency(snapshots: snapshots, asOf: now),
                feeling: feeling,
                date: now
            )
        )
        let recommendation = recommendationEngine.recommendation(
            for: RecommendationInput(
                scoreResult: score,
                preferredActivities: preferences.preferredActivities,
                preferredWorkoutMinutes: preferences.preferredWorkoutMinutes,
                equipment: preferences.equipment,
                soreness: soreness,
                feeling: feeling,
                corridorDay: corridor.today
            )
        )
        return ReadinessSnapshot(
            score: score,
            recommendation: recommendation,
            deltas: deltas,
            recentLoad: recentLoad,
            history: snapshots,
            workoutHistory: workouts,
            corridor: corridor,
            streak: streak
        )
    }
}
